import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/rankings/data/ranking_sort.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/navigation/app_sort_menu_button.dart';

/// 榜单排序入口适配器。
///
/// `selectedSortField == null` 表示「默认（名次）」；只有选了字段才显示升降序。
class RankingSortMenuButton extends StatelessWidget {
  const RankingSortMenuButton({
    super.key,
    required this.filterState,
    required this.onSortChanged,
    this.useDrawer = false,
    this.glassGrouped = false,
    this.iconOnly = false,
    this.keyPrefix = 'rankings',
    this.triggerKey,
    this.panelKey,
    this.drawerKey,
  });

  final RankingFilterState filterState;
  final void Function(RankingSortField? field, SortDirection direction)
  onSortChanged;
  final bool useDrawer;
  final bool glassGrouped;
  final bool iconOnly;
  final String keyPrefix;
  final Key? triggerKey;
  final Key? panelKey;
  final Key? drawerKey;

  @override
  Widget build(BuildContext context) {
    return AppSortMenuButton<RankingSortField>(
      fields: [
        for (final field in RankingSortField.values)
          if (field != RankingSortField.rank) field,
      ],
      selectedField: filterState.selectedSortField,
      fieldLabelBuilder: (value) => value.label(AppLocalizations.of(context)),
      onFieldChanged: (value) =>
          onSortChanged(value, filterState.selectedSortDirection),
      selectedDirection: filterState.selectedSortDirection,
      onDirectionChanged: (value) =>
          onSortChanged(filterState.selectedSortField, value),
      allowDefaultOption: true,
      defaultOptionLabel: AppLocalizations.of(context).widgetRankingSortDefault,
      directionVisibleWhen: (field) => field != null,
      useDrawer: useDrawer,
      glassGrouped: glassGrouped,
      iconOnly: iconOnly,
      triggerKey: triggerKey,
      panelKey: panelKey,
      drawerKey: drawerKey,
      fieldKeyBuilder: (value) =>
          Key('$keyPrefix-sort-field-${value.apiValue}'),
      directionKeyBuilder: (value) =>
          Key('$keyPrefix-sort-direction-${value.apiValue}'),
      defaultOptionKey: Key('$keyPrefix-sort-default'),
    );
  }
}
