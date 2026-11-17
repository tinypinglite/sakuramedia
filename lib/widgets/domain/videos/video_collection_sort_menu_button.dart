import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collection_sort.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/navigation/app_sort_menu_button.dart';

/// 视频合集详情成员排序的入口适配器。
///
/// 「手动顺序」对应 `field == null`，方向分节隐藏；选字段后才显示升降序。
class VideoCollectionSortMenuButton extends StatelessWidget {
  const VideoCollectionSortMenuButton({
    super.key,
    required this.sort,
    required this.onChanged,
    this.useDrawer = false,
    this.glassGrouped = false,
    this.iconOnly = false,
    this.keyPrefix = 'video-collection',
    this.triggerKey,
    this.panelKey,
    this.drawerKey,
    this.fieldControlKey,
    this.directionControlKey,
  });

  final VideoCollectionSort sort;

  /// [field] 为 `null` 表示切回手动顺序；[direction] 为 `null` 表示沿用当前方向。
  final void Function({
    required VideoSortField? field,
    SortDirection? direction,
  })
  onChanged;

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
    final l10n = AppLocalizations.of(context);
    return AppSortMenuButton<VideoSortField>(
      fields: VideoSortField.values,
      selectedField: sort.field,
      fieldLabelBuilder: (value) => value.labelWith(l10n),
      onFieldChanged: (value) => onChanged(field: value),
      selectedDirection: sort.direction,
      onDirectionChanged: (value) =>
          onChanged(field: sort.field, direction: value),
      allowDefaultOption: true,
      defaultOptionLabel: l10n.widgetVideoSortManual,
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
