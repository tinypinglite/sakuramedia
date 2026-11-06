import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/navigation/app_sort_menu_button.dart';

/// 女优列表的排序入口适配器。
///
/// 搜索态下接口按相关度排序，排序字段不生效；入口显示「相关度」并禁用，
/// 避免摘要与实际结果不一致。
class ActorSortMenuButton extends StatelessWidget {
  const ActorSortMenuButton({
    super.key,
    required this.filterState,
    required this.onChanged,
    this.useDrawer = false,
    this.glassGrouped = false,
    this.iconOnly = false,
    this.keyPrefix = 'actors',
    this.triggerKey,
    this.panelKey,
    this.drawerKey,
  });

  final ActorFilterState filterState;
  final ValueChanged<ActorFilterState> onChanged;
  final bool useDrawer;
  final bool glassGrouped;
  final bool iconOnly;
  final String keyPrefix;
  final Key? triggerKey;
  final Key? panelKey;
  final Key? drawerKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final searching = filterState.isSearching;
    final relevance = filterState.usesRelevanceSort;
    return AppSortMenuButton<ActorSortField>(
      fields: ActorSortField.values,
      selectedField: filterState.sortField,
      fieldLabelBuilder: (value) => value.label(AppLocalizations.of(context)),
      onFieldChanged: (value) =>
          onChanged(filterState.copyWith(sortField: value!)),
      selectedDirection: filterState.sortDirection,
      onDirectionChanged: (value) =>
          onChanged(filterState.copyWith(sortDirection: value)),
      useDrawer: useDrawer,
      glassGrouped: glassGrouped,
      iconOnly: iconOnly,
      enabled: !searching,
      triggerLabel: relevance ? l10n.widgetActorSortRelevance : null,
      tooltip: relevance
          ? l10n.widgetActorSortRelevanceTooltip
          : (searching
                ? l10n.widgetActorSortDisabledWhileSearching
                : l10n.widgetActorSort),
      triggerKey: triggerKey,
      panelKey: panelKey,
      drawerKey: drawerKey,
      fieldKeyBuilder: (value) => Key('$keyPrefix-sort-field-${value.name}'),
      directionKeyBuilder: (value) =>
          Key('$keyPrefix-sort-direction-${value.name}'),
    );
  }
}
