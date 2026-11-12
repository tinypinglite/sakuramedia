import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/navigation/app_sort_menu_button.dart';

/// 播放列表影片列表的排序入口适配器。
///
/// `sortField == null` 表示走后端默认顺序，摘要显示「最近触达」；只有选了字段
/// 才显示升降序。
class PlaylistSortMenuButton extends ConsumerWidget {
  const PlaylistSortMenuButton({
    super.key,
    required this.filterState,
    required this.onChanged,
    this.useDrawer = false,
    this.glassGrouped = false,
    this.iconOnly = false,
    this.keyPrefix = 'playlist',
    this.triggerKey,
    this.panelKey,
    this.drawerKey,
    this.fieldControlKey,
    this.directionControlKey,
  });

  final PlaylistFilterState filterState;
  final ValueChanged<PlaylistFilterState> onChanged;
  final bool useDrawer;
  final bool glassGrouped;
  final bool iconOnly;
  final String keyPrefix;
  final Key? triggerKey;
  final Key? panelKey;
  final Key? drawerKey;
  final Key? fieldControlKey;
  final Key? directionControlKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsEnabled = ref.watch(statsFeaturesEnabledProvider);
    final effectiveState = statsEnabled
        ? filterState
        : filterState.withoutStatsFeatures();
    return AppSortMenuButton<PlaylistSortField>(
      fields: visiblePlaylistSortFields(statsEnabled: statsEnabled),
      selectedField: effectiveState.sortField,
      fieldLabelBuilder: (value) => value.label(AppLocalizations.of(context)),
      onFieldChanged: (value) =>
          onChanged(effectiveState.copyWith(sortField: value)),
      selectedDirection: effectiveState.sortDirection,
      onDirectionChanged: (value) =>
          onChanged(effectiveState.copyWith(sortDirection: value)),
      allowDefaultOption: true,
      defaultOptionLabel: AppLocalizations.of(context).playlistSortDefault,
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
      fieldControlKey: fieldControlKey,
      directionControlKey: directionControlKey,
    );
  }
}
