import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_provider.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/activity_task_run_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/activity/activity_task_sort_menu_button.dart';

/// 「任务历史」的筛选条：状态、任务、触发来源与排序。
///
/// 桌面端是一行下拉 + 排序菜单，移动端是摘要 + 排序菜单 + 筛选抽屉。
class ActivityTaskFilterBar extends StatelessWidget {
  const ActivityTaskFilterBar({super.key, required this.controller});

  final ActivityCenter controller;

  static const List<String> states = <String>['running', 'completed', 'failed'];
  static const List<String> triggerTypes = <String>[
    'scheduled',
    'manual',
    'startup',
    'internal',
    'plugin',
  ];

  @override
  Widget build(BuildContext context) {
    if (AppPlatformScope.maybeOf(context) == AppPlatform.mobile) {
      return _MobileTaskFilterEntry(controller: controller);
    }
    final l10n = AppLocalizations.of(context);
    final taskKeyLabels = controller.knownTaskKeyLabels;
    final filter = controller.taskFilter;
    final taskKeyOptions = <String>{
      ...controller.knownTaskKeys,
      if (filter.taskKey != null) filter.taskKey!,
    }.toList(growable: false);
    final stateOptions = <String>{
      ...ActivityTaskFilterBar.states,
      if (filter.state != null) filter.state!,
    }.toList(growable: false);
    final triggerOptions = <String>{
      ...ActivityTaskFilterBar.triggerTypes,
      if (filter.triggerType != null) filter.triggerType!,
    }.toList(growable: false);

    void apply(ActivityTaskFilterState next) {
      unawaited(controller.applyTaskFilter(next));
    }

    return AppGlassListHeader(
      leading: AppGlassFilterPopover(
        panelKey: const Key('activity-task-filter-panel'),
        scrollable: true,
        isDefault: !filter.hasActiveFilters,
        onReset: () => apply(filter.resetFilters()),
        resetKey: const Key('activity-task-filter-reset'),
        triggerKey: const Key('activity-task-filter-trigger'),
        label: _taskFilterSummary(filter, taskKeyLabels, l10n),
        tooltip: l10n.activityTaskFilterTitle,
        panelBuilder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppFilterChoiceSection<String?>(
              title: l10n.activityTaskStateLabel,
              controlKey: const Key('activity-task-state-filter'),
              items: <AppSegmentedItem<String?>>[
                AppSegmentedItem(
                  value: null,
                  label: l10n.activityFilterAllStates,
                ),
                for (final value in stateOptions)
                  AppSegmentedItem(
                    value: value,
                    label: activityTaskStateLabel(value, l10n),
                  ),
              ],
              selected: filter.state,
              onChanged: (value) => apply(filter.copyWith(state: value)),
            ),
            SizedBox(height: context.appSpacing.lg),
            AppFilterChoiceSection<String?>(
              title: l10n.activityTaskTypeLabel,
              controlKey: const Key('activity-task-key-filter'),
              items: <AppSegmentedItem<String?>>[
                AppSegmentedItem(
                  value: null,
                  label: l10n.activityFilterAllTaskTypes,
                ),
                for (final value in taskKeyOptions)
                  AppSegmentedItem(
                    value: value,
                    label: taskKeyLabels[value] ?? value,
                  ),
              ],
              selected: filter.taskKey,
              onChanged: (value) => apply(filter.copyWith(taskKey: value)),
            ),
            SizedBox(height: context.appSpacing.lg),
            AppFilterChoiceSection<String?>(
              title: l10n.activityTaskTriggerLabel,
              controlKey: const Key('activity-task-trigger-filter'),
              items: <AppSegmentedItem<String?>>[
                AppSegmentedItem(value: null, label: l10n.activityAll),
                for (final value in triggerOptions)
                  AppSegmentedItem(
                    value: value,
                    label: activityTriggerTypeLabel(value, l10n),
                  ),
              ],
              selected: filter.triggerType,
              onChanged: (value) => apply(filter.copyWith(triggerType: value)),
            ),
          ],
        ),
      ),
      trailing: ActivityTaskSortMenuButton(
        triggerKey: const Key('activity-task-sort-trigger'),
        panelKey: const Key('activity-task-sort-panel'),
        filterState: filter,
        onChanged: apply,
      ),
    );
  }
}

class _MobileTaskFilterEntry extends StatelessWidget {
  const _MobileTaskFilterEntry({required this.controller});

  final ActivityCenter controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filter = controller.taskFilter;
    final taskKeyLabels = controller.knownTaskKeyLabels;
    final summary = _taskFilterSummary(filter, taskKeyLabels, l10n);
    return AppMobileListHeader(
      leading: AppMobileHeaderText(
        title: l10n.activityTaskRunHistoryTitle,
        countLabel: summary,
      ),
      actions: <Widget>[
        AppGlassFilterIconButton(
          key: const Key('mobile-activity-task-filter-button'),
          summary: summary,
          isActive: filter.hasActiveFilters,
          onPressed: () => unawaited(
            _showMobileActivityTaskFilterDrawer(
              context,
              current: filter,
              taskKeyLabels: taskKeyLabels,
              onChanged: (next) => unawaited(controller.applyTaskFilter(next)),
            ),
          ),
        ),
        ActivityTaskSortMenuButton(
          triggerKey: const Key('mobile-activity-task-sort-trigger'),
          drawerKey: const Key('mobile-activity-task-sort-drawer'),
          keyPrefix: 'mobile-activity-task',
          filterState: filter,
          onChanged: (next) => unawaited(controller.applyTaskFilter(next)),
          useDrawer: true,
          iconOnly: true,
        ),
      ],
    );
  }
}

Future<void> _showMobileActivityTaskFilterDrawer(
  BuildContext context, {
  required ActivityTaskFilterState current,
  required Map<String, String> taskKeyLabels,
  required ValueChanged<ActivityTaskFilterState> onChanged,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-activity-task-filter-drawer'),
    maxHeightFactor: 0.68,
    builder: (_) => AppMobileFilterDrawer<ActivityTaskFilterState>(
      current: current,
      initial: current.resetFilters(),
      onChanged: onChanged,
      isDefault: (value) => !value.hasActiveFilters,
      scrollViewKey: const Key('mobile-activity-task-filter-scroll-view'),
      contentBuilder: (context, local, onApply) => _MobileTaskFilterSections(
        filter: local,
        taskKeyLabels: taskKeyLabels,
        onChanged: onApply,
      ),
    ),
  );
}

class _MobileTaskFilterSections extends StatelessWidget {
  const _MobileTaskFilterSections({
    required this.filter,
    required this.taskKeyLabels,
    required this.onChanged,
  });

  final ActivityTaskFilterState filter;
  final Map<String, String> taskKeyLabels;
  final ValueChanged<ActivityTaskFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.activityTaskFilterTitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        AppFilterChoiceSection<String?>(
          title: l10n.activityTaskStateLabel,
          controlKey: const Key('mobile-activity-task-state-filter'),
          items: <AppSegmentedItem<String?>>[
            AppSegmentedItem<String?>(
              value: null,
              label: l10n.activityFilterAllStates,
            ),
            ...ActivityTaskFilterBar.states.map(
              (value) => AppSegmentedItem<String?>(
                value: value,
                label: activityTaskStateLabel(value, l10n),
              ),
            ),
          ],
          selected: filter.state,
          onChanged: (value) => onChanged(filter.copyWith(state: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        AppFilterChoiceSection<String?>(
          title: l10n.activityTaskTypeLabel,
          controlKey: const Key('mobile-activity-task-key-filter'),
          items: <AppSegmentedItem<String?>>[
            AppSegmentedItem<String?>(
              value: null,
              label: l10n.activityFilterAllTaskTypes,
            ),
            ...taskKeyLabels.entries.map(
              (entry) => AppSegmentedItem<String?>(
                value: entry.key,
                label: entry.value,
              ),
            ),
          ],
          selected: filter.taskKey,
          onChanged: (value) => onChanged(filter.copyWith(taskKey: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        AppFilterChoiceSection<String?>(
          title: l10n.activityTaskTriggerLabel,
          controlKey: const Key('mobile-activity-task-trigger-filter'),
          items: <AppSegmentedItem<String?>>[
            AppSegmentedItem<String?>(
              value: null,
              label: l10n.activityFilterAllTriggers,
            ),
            ...ActivityTaskFilterBar.triggerTypes.map(
              (value) => AppSegmentedItem<String?>(
                value: value,
                label: activityTriggerTypeLabel(value, l10n),
              ),
            ),
          ],
          selected: filter.triggerType,
          onChanged: (value) => onChanged(filter.copyWith(triggerType: value)),
        ),
      ],
    );
  }
}

String _taskFilterSummary(
  ActivityTaskFilterState filter,
  Map<String, String> taskKeyLabels,
  AppLocalizations l10n,
) {
  final values = <String>[];
  if (filter.state != null) {
    values.add(activityTaskStateLabel(filter.state!, l10n));
  }
  if (filter.taskKey != null) {
    values.add(taskKeyLabels[filter.taskKey] ?? filter.taskKey!);
  }
  if (filter.triggerType != null) {
    values.add(activityTriggerTypeLabel(filter.triggerType!, l10n));
  }
  return values.isEmpty ? l10n.activityFilterAllTasks : values.join(' · ');
}
