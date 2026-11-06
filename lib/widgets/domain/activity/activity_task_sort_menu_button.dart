import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/activity/presentation/activity_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/navigation/app_sort_menu_button.dart';

/// 活动中心任务列表的排序入口适配器。
class ActivityTaskSortMenuButton extends StatelessWidget {
  const ActivityTaskSortMenuButton({
    super.key,
    required this.filterState,
    required this.onChanged,
    this.useDrawer = false,
    this.iconOnly = false,
    this.keyPrefix = 'activity-task',
    this.triggerKey,
    this.panelKey,
    this.drawerKey,
  });

  final ActivityTaskFilterState filterState;
  final ValueChanged<ActivityTaskFilterState> onChanged;
  final bool useDrawer;
  final bool iconOnly;
  final String keyPrefix;
  final Key? triggerKey;
  final Key? panelKey;
  final Key? drawerKey;

  @override
  Widget build(BuildContext context) {
    return AppSortMenuButton<ActivityTaskSortField>(
      fields: ActivityTaskSortField.values,
      selectedField: filterState.sortField,
      fieldLabelBuilder: (value) => value.label(AppLocalizations.of(context)),
      onFieldChanged: (value) => onChanged(filterState.withSortField(value!)),
      selectedDirection: filterState.sortDirection,
      onDirectionChanged: (value) =>
          onChanged(filterState.withSortDirection(value)),
      useDrawer: useDrawer,
      iconOnly: iconOnly,
      triggerKey: triggerKey,
      panelKey: panelKey,
      drawerKey: drawerKey,
      fieldKeyBuilder: (value) => Key('$keyPrefix-sort-field-${value.name}'),
      directionKeyBuilder: (value) =>
          Key('$keyPrefix-sort-direction-${value.name}'),
    );
  }
}
