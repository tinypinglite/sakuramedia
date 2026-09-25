import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_cover_hover_info.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_check_badge.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 非 JAV 视频列表卡片：整卡即封面，收起态不铺任何文字。
///
/// 与 `MovieSummaryCard` / `ClipGridCard` 同属一套「封面即卡片」范式：桌面端指针
/// 悬停时底部渐显压暗层，标题、时长/大小与靠左的播放键自下而上淡入；触摸端没有
/// hover（移动端靠点击弹动作抽屉、长按多选），停在收起态。悬停展开/收起与封面推近
/// 由 [AppCoverHoverInfo] 提供——与 JAV 影片卡同为 180ms ease-out，系统开启
/// 「减弱动态效果」时退化为瞬时切换。
///
/// 加入合集 / 跳到合集 / 删除等动作走桌面动作弹窗（`showDesktopVideoActionsDialog`）
/// 或移动端 sheet（`showMobileVideoActionsSheet`）——由 onTap 回调统一承载，卡片
/// 本身不再挂右键 / 长按上下文菜单。
///
/// 与 [MovieListItemDto] 平行，但去掉订阅/热度/番号等 JAV 概念，主键为
/// [VideoItemListItemDto.id]。
class VideoSummaryCard extends StatelessWidget {
  const VideoSummaryCard({
    super.key,
    required this.video,
    this.onTap,
    this.onPlay,
    this.onThumbnails,
    this.onAddToCollection,
    this.onDelete,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
  });

  final VideoItemListItemDto video;

  /// 点击卡片：桌面走动作弹窗、移动走 sheet；两端弹窗内承载播放/加入合集/删除等。
  final VoidCallback? onTap;

  /// 悬停面板里的播放主按钮回调；为 `null` 或 [VideoItemListItemDto.canPlay]
  /// 为 false 时不显示按钮。
  final VoidCallback? onPlay;

  /// 悬停面板里的「缩略图」动作；为 `null` 时不显示按钮。
  final VoidCallback? onThumbnails;

  /// 悬停面板里的「加入合集」动作；为 `null` 时不显示按钮。
  final VoidCallback? onAddToCollection;

  /// 悬停面板里的「删除」动作；为 `null` 时不显示按钮。
  final VoidCallback? onDelete;

  /// 选择模式:整卡点击改为切换选中,不展开悬停面板,叠加勾选标记。
  final bool selectionMode;

  /// 当前是否被选中（仅 [selectionMode] 下有意义）。
  final bool isSelected;

  /// 选择模式下切换选中态的回调，入参为切换后的目标值。
  final ValueChanged<bool>? onSelectedChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final selected = selectionMode && isSelected;
    final interactive = selectionMode
        ? onSelectedChanged != null
        : onTap != null;

    return Material(
      key: Key('video-summary-card-${video.id}'),
      color: Colors.transparent,
      child: InkWell(
        key: selectionMode
            ? Key('video-summary-card-select-${video.id}')
            : Key('video-summary-card-tap-${video.id}'),
        mouseCursor: interactive
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        borderRadius: context.appRadius.lgBorder,
        onTap: selectionMode
            ? () => onSelectedChanged?.call(!isSelected)
            : onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: context.appRadius.lgBorder,
            border: Border.all(
              color: selected ? colors.selectionBorder : colors.borderSubtle,
              width: selected ? 2 : 1,
            ),
            boxShadow: context.appShadows.card,
          ),
          child: ClipRRect(
            borderRadius: context.appRadius.lgBorder,
            // 骨架态整卡收敛成一块 shimmer 圆角块（非骨架态原样渲染）。
            child: Skeleton.unite(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppCoverHoverInfo(
                    enabled: !selectionMode,
                    cover: _VideoCover(
                      videoId: video.id,
                      coverImage: video.coverImage,
                    ),
                    infoBuilder: (context) => _buildHoverInfo(context),
                  ),
                  if (selectionMode)
                    Positioned(
                      top: context.appSpacing.xs,
                      left: context.appSpacing.xs,
                      child: IgnorePointer(
                        child: SelectionCheckBadge(isSelected: isSelected),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 悬停展开内容：单行「标题 + 时长 · 大小」，下方一整行动作按钮
  /// （播放 / 缩略图 / 加入合集 / 删除，按回调是否为空显隐）。
  Widget _buildHoverInfo(BuildContext context) {
    final spacing = context.appSpacing;
    final play = onPlay;
    final canPlay = play != null && video.canPlay;
    final thumbnails = onThumbnails;
    final addToCollection = onAddToCollection;
    final delete = onDelete;
    final actions = <Widget>[
      if (canPlay)
        AppCoverHoverActionButton(
          key: Key('video-summary-card-play-${video.id}'),
          icon: Icons.play_arrow_rounded,
          onTap: play,
          primary: true,
          tooltip: '播放',
        ),
      if (thumbnails != null)
        AppCoverHoverActionButton(
          key: Key('video-summary-card-thumbnails-${video.id}'),
          icon: Icons.photo_library_outlined,
          onTap: thumbnails,
          tooltip: '缩略图',
        ),
      if (addToCollection != null)
        AppCoverHoverActionButton(
          key: Key('video-summary-card-add-collection-${video.id}'),
          icon: Icons.playlist_add_rounded,
          onTap: addToCollection,
          tooltip: '加入合集',
        ),
      if (delete != null)
        AppCoverHoverActionButton(
          key: Key('video-summary-card-delete-${video.id}'),
          icon: Icons.delete_outline_rounded,
          onTap: delete,
          tooltip: '删除',
        ),
    ];
    return Column(
      key: Key('video-summary-card-info-${video.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppCoverHoverInfoRow(label: video.preferredTitle, meta: _metaLine()),
        if (actions.isNotEmpty) ...[
          SizedBox(height: spacing.sm),
          AppCoverHoverActionBar(actions: actions),
        ],
      ],
    );
  }

  /// 副信息行：时长 · 大小；两者都缺时返回 `null`（不渲染该行）。
  String? _metaLine() {
    final parts = <String>[
      if (video.durationSeconds > 0) formatMediaTimecode(video.durationSeconds),
      if (video.fileSizeBytes > 0) formatFileSize(video.fileSizeBytes),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _VideoCover extends StatelessWidget {
  const _VideoCover({required this.videoId, required this.coverImage});

  final int videoId;
  final MovieImageDto? coverImage;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final coverUrl = coverImage?.bestAvailableUrl.trim();

    if (coverUrl != null && coverUrl.isNotEmpty) {
      // 瀑布流网格按 coverWidth/coverHeight 切 tile，cover 填满不再留底色；
      // 罕见极端比例（探测缺失走 16:9 fallback、与真实比例差距大）会少量裁切。
      return MaskedImage(url: coverUrl, fit: BoxFit.cover);
    }

    return DecoratedBox(
      key: Key('video-summary-card-placeholder-$videoId'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfaceMuted,
            Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.38),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.video_library_outlined,
          size: componentTokens.iconSize3xl,
          color: context.appTextPalette.muted,
        ),
      ),
    );
  }
}
