import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/features/activity/presentation/providers/activity_center_provider.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/activity_task_run_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/domain/activity/activity_task_sort_menu_button.dart';

/// 「最近操作 / 运行记录」的筛选条：状态、任务、触发来源与排序。
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
    final layoutTokens = context.appLayoutTokens;
    final taskKeyLabels = controller.knownTaskKeyLabels;
    final filterTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.tertiary,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.appSpacing.md,
      runSpacing: context.appSpacing.md,
      children: [
        SizedBox(
          width: layoutTokens.filterFieldWidthMd,
          child: AppSelectField<String?>(
            key: const Key('activity-task-state-filter'),
            value: controller.taskFilter.state,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: <DropdownMenuItem<String?>>[
              DropdownMenuItem<String?>(
                value: null,
                child: Text(l10n.activityFilterAllStates),
              ),
              ...states.map(
                (value) => DropdownMenuItem<String?>(
                  value: value,
                  child: Text(activityTaskStateLabel(value, l10n)),
                ),
              ),
            ],
            onChanged: (value) => controller.applyTaskFilter(
              controller.taskFilter.copyWith(state: value),
            ),
          ),
        ),
        SizedBox(
          width: layoutTokens.filterFieldWidthLg,
          child: AppSelectField<String?>(
            key: const Key('activity-task-key-filter'),
            value: controller.taskFilter.taskKey,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: <DropdownMenuItem<String?>>[
              DropdownMenuItem<String?>(
                value: null,
                child: Text(l10n.activityFilterAllTaskTypes),
              ),
              ...controller.knownTaskKeys.map(
                (value) => DropdownMenuItem<String?>(
                  value: value,
                  child: Text(taskKeyLabels[value] ?? value),
                ),
              ),
            ],
            onChanged: (value) => controller.applyTaskFilter(
              controller.taskFilter.copyWith(taskKey: value),
            ),
          ),
        ),
        SizedBox(
          width: layoutTokens.filterFieldWidthMd,
          child: AppSelectField<String?>(
            key: const Key('activity-task-trigger-filter'),
            value: controller.taskFilter.triggerType,
            size: AppSelectFieldSize.compact,
            textStyle: filterTextStyle,
            items: <DropdownMenuItem<String?>>[
              DropdownMenuItem<String?>(
                value: null,
                child: Text(l10n.activityFilterAllTriggers),
              ),
              ...triggerTypes.map(
                (value) => DropdownMenuItem<String?>(
                  value: value,
                  child: Text(activityTriggerTypeLabel(value, l10n)),
                ),
              ),
            ],
            onChanged: (value) => controller.applyTaskFilter(
              controller.taskFilter.copyWith(triggerType: value),
            ),
          ),
        ),
        SizedBox(
          height: context.appComponentTokens.mobileTopTabHeight,
          child: ActivityTaskSortMenuButton(
            triggerKey: const Key('activity-task-sort-trigger'),
            panelKey: const Key('activity-task-sort-panel'),
            filterState: controller.taskFilter,
            onChanged: controller.applyTaskFilter,
          ),
        ),
      ],
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
    return AppListHeader(
      filterButtonKey: const Key('mobile-activity-task-filter-button'),
      filterLabel: _taskFilterSummary(filter, taskKeyLabels, l10n),
      filterTooltip: l10n.activityTaskFilterTitle,
      onFilterTap: () => unawaited(
        _showMobileActivityTaskFilterDrawer(
          context,
          current: filter,
          taskKeyLabels: taskKeyLabels,
          onChanged: (next) => unawaited(controller.applyTaskFilter(next)),
        ),
      ),
      actionSlots: [
        ActivityTaskSortMenuButton(
          triggerKey: const Key('mobile-activity-task-sort-trigger'),
          drawerKey: const Key('mobile-activity-task-sort-drawer'),
          keyPrefix: 'mobile-activity-task',
          filterState: filter,
          onChanged: (next) => unawaited(controller.applyTaskFilter(next)),
          useDrawer: true,
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
        AppSelectField<String?>(
          key: const Key('mobile-activity-task-state-filter'),
          label: l10n.activityTaskStateLabel,
          value: filter.state,
          items: <DropdownMenuItem<String?>>[
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.activityFilterAllStates),
            ),
            ...ActivityTaskFilterBar.states.map(
              (value) => DropdownMenuItem<String?>(
                value: value,
                child: Text(activityTaskStateLabel(value, l10n)),
              ),
            ),
          ],
          onChanged: (value) => onChanged(filter.copyWith(state: value)),
        ),
        SizedBox(height: context.appSpacing.md),
        AppSelectField<String?>(
          key: const Key('mobile-activity-task-key-filter'),
          label: l10n.activityTaskTypeLabel,
          value: filter.taskKey,
          items: <DropdownMenuItem<String?>>[
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.activityFilterAllTaskTypes),
            ),
            ...taskKeyLabels.entries.map(
              (entry) => DropdownMenuItem<String?>(
                value: entry.key,
                child: Text(entry.value),
              ),
            ),
          ],
          onChanged: (value) => onChanged(filter.copyWith(taskKey: value)),
        ),
        SizedBox(height: context.appSpacing.md),
        AppSelectField<String?>(
          key: const Key('mobile-activity-task-trigger-filter'),
          label: l10n.activityTaskTriggerLabel,
          value: filter.triggerType,
          items: <DropdownMenuItem<String?>>[
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.activityFilterAllTriggers),
            ),
            ...ActivityTaskFilterBar.triggerTypes.map(
              (value) => DropdownMenuItem<String?>(
                value: value,
                child: Text(activityTriggerTypeLabel(value, l10n)),
              ),
            ),
          ],
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
