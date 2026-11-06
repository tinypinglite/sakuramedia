import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/navigation/app_sort_menu_button.dart';

/// 播放列表影片列表的排序入口适配器。
///
/// `sortField == null` 表示走后端默认顺序，摘要显示「最近触达」；只有选了字段
/// 才显示升降序。
class PlaylistSortMenuButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AppSortMenuButton<PlaylistSortField>(
      fields: PlaylistSortField.values,
      selectedField: filterState.sortField,
      fieldLabelBuilder: (value) => value.label(AppLocalizations.of(context)),
      onFieldChanged: (value) =>
          onChanged(filterState.copyWith(sortField: value)),
      selectedDirection: filterState.sortDirection,
      onDirectionChanged: (value) =>
          onChanged(filterState.copyWith(sortDirection: value)),
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
