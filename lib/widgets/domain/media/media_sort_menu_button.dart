import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/navigation/app_sort_menu_button.dart';

/// 媒体浏览列表的排序入口适配器。
///
/// `sortField == null` 表示走后端默认（入库时间倒序），摘要显示「默认排序」；
/// 只有选了字段才显示升降序。
class MediaSortMenuButton extends ConsumerWidget {
  const MediaSortMenuButton({
    super.key,
    required this.filterState,
    required this.onChanged,
    this.useDrawer = false,
    this.glassGrouped = false,
    this.iconOnly = false,
    this.keyPrefix = 'media',
    this.triggerKey,
    this.panelKey,
    this.drawerKey,
  });

  final MediaBrowseFilterState filterState;
  final ValueChanged<MediaBrowseFilterState> onChanged;
  final bool useDrawer;
  final bool glassGrouped;
  final bool iconOnly;
  final String keyPrefix;
  final Key? triggerKey;
  final Key? panelKey;
  final Key? drawerKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statsEnabled = ref.watch(statsFeaturesEnabledProvider);
    final effectiveState = statsEnabled
        ? filterState
        : filterState.withoutStatsFeatures();
    return AppSortMenuButton<MediaBrowseSortField>(
      fields: visibleMediaBrowseSortFields(statsEnabled: statsEnabled),
      selectedField: effectiveState.sortField,
      fieldLabelBuilder: (value) => value.labelWith(l10n: l10n),
      onFieldChanged: (value) =>
          onChanged(effectiveState.copyWith(sortField: value)),
      selectedDirection: effectiveState.sortDirection,
      onDirectionChanged: (value) =>
          onChanged(effectiveState.copyWith(sortDirection: value)),
      allowDefaultOption: true,
      defaultOptionLabel: l10n.widgetMediaSortDefault,
      directionVisibleWhen: (field) => field != null,
      useDrawer: useDrawer,
      glassGrouped: glassGrouped,
      iconOnly: iconOnly,
      triggerKey: triggerKey,
      panelKey: panelKey,
      drawerKey: drawerKey,
      fieldKeyBuilder: (value) => Key('$keyPrefix-sort-field-${value.name}'),
      directionKeyBuilder: (value) =>
          Key('$keyPrefix-sort-direction-${value.name}'),
      defaultOptionKey: Key('$keyPrefix-sort-default'),
    );
  }
}
