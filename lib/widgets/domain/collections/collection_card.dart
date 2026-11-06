import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_cover_card.dart';

/// 合集封面卡：16:9 封面 + 名称 + 计数角标，「编辑 / 删除」走右键 / 长按菜单。
///
/// 切片 / 视频 / 时刻合集结构完全一致，仅在 DTO、计数字段、占位与计数角标图标、
/// 封面 `fit` 与 key 前缀上有差异，统一为本卡片的 [CollectionCard.clip] /
/// [CollectionCard.video] / [CollectionCard.moment] 命名构造，各自把差异封装在一处。
/// 底层渲染仍复用 [CollectionCoverCard]。
///
/// 用于合集主页横滑区（仅 [onTap]）与合集列表网格（带 [onEdit] / [onDelete]）。
/// 卡片宽度由调用方通过外层约束（如 `SizedBox(width: ...)`）控制。
class CollectionCard extends StatelessWidget {
  const CollectionCard._({
    super.key,
    required this.tapKey,
    required this.menuKey,
    required this.title,
    required this.count,
    required this.countIcon,
    required this.coverUrl,
    required this.coverFit,
    required this.placeholderIcon,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.glassChrome = false,
    this.coverBackdrop = false,
  });

  /// 视频合集卡。封面取自某个视频的首帧、可能是竖图，故 `fit: contain` 完整展示。
  factory CollectionCard.video({
    Key? key,
    required VideoCollectionDto collection,
    required VoidCallback onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
    bool coverBackdrop = false,
  }) {
    return CollectionCard._(
      key: key,
      tapKey: Key('video-collection-card-tap-${collection.id}'),
      menuKey: Key('video-collection-more-${collection.id}'),
      title: collection.name,
      count: collection.itemCount,
      countIcon: Icons.video_collection_rounded,
      coverUrl: collection.coverImage?.origin,
      coverFit: BoxFit.contain,
      placeholderIcon: Icons.video_collection_outlined,
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
      glassChrome: true,
      coverBackdrop: coverBackdrop,
    );
  }

  /// 时刻合集卡。缩略图为 16:9 横图，故 `fit: cover` 铺满。
  factory CollectionCard.moment({
    Key? key,
    required MomentCollectionDto collection,
    required VoidCallback onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return CollectionCard._(
      key: key,
      tapKey: Key('moment-collection-card-${collection.id}'),
      menuKey: Key('moment-collection-more-${collection.id}'),
      title: collection.name,
      count: collection.pointCount,
      countIcon: Icons.bookmarks_rounded,
      coverUrl: collection.coverImage?.origin,
      coverFit: BoxFit.cover,
      placeholderIcon: Icons.bookmarks_outlined,
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }

  /// 切片合集卡。缩略图为 16:9 横图，故 `fit: cover` 铺满。
  factory CollectionCard.clip({
    Key? key,
    required ClipCollectionDto collection,
    required VoidCallback onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return CollectionCard._(
      key: key,
      tapKey: Key('clip-collection-card-tap-${collection.id}'),
      menuKey: Key('clip-collection-more-${collection.id}'),
      title: collection.name,
      count: collection.clipCount,
      countIcon: Icons.video_library_rounded,
      coverUrl: collection.coverImage?.origin,
      coverFit: BoxFit.cover,
      placeholderIcon: Icons.video_library_outlined,
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }

  final Key tapKey;
  final Key menuKey;
  final String title;
  final int count;
  final IconData countIcon;
  final String? coverUrl;
  final BoxFit coverFit;
  final IconData placeholderIcon;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// 封面内浮玻璃信息条；桌面玻璃合集页使用。
  final bool glassChrome;

  /// contain 封面两侧是否铺同图暗底；移动端竖图合集卡使用。
  final bool coverBackdrop;

  @override
  Widget build(BuildContext context) {
    return CollectionCoverCard(
      tapKey: tapKey,
      menuKey: menuKey,
      title: title,
      count: count,
      countIcon: countIcon,
      coverUrl: coverUrl,
      coverFit: coverFit,
      placeholderIcon: placeholderIcon,
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
      glassChrome: glassChrome,
      coverBackdrop: coverBackdrop,
    );
  }
}
