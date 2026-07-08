import 'package:flutter/material.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/widgets/collections/collection_cover_card.dart';

/// 合集封面卡：16:9 封面 + 名称 + 计数角标，右上角可选「···」菜单（编辑 / 删除）。
///
/// 切片合集与视频合集结构完全一致，仅在 DTO、计数字段、占位图标、封面 `fit` 与 key
/// 前缀上有差异，此前由 `ClipCollectionCard` / `VideoCollectionCard` 两个近乎相同的
/// 薄适配层承载，现统一为本卡片的 [CollectionCard.clip] / [CollectionCard.video]
/// 两个命名构造，各自把差异封装在一处。底层渲染仍复用 [CollectionCoverCard]。
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
    required this.coverUrl,
    required this.coverFit,
    required this.placeholderIcon,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  /// 视频合集卡。封面取自某个视频的首帧、可能是竖图，故 `fit: contain` 完整展示。
  factory CollectionCard.video({
    Key? key,
    required VideoCollectionDto collection,
    required VoidCallback onTap,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return CollectionCard._(
      key: key,
      tapKey: Key('video-collection-card-tap-${collection.id}'),
      menuKey: Key('video-collection-more-${collection.id}'),
      title: collection.name,
      count: collection.itemCount,
      coverUrl: collection.coverImage?.bestAvailableUrl,
      coverFit: BoxFit.contain,
      placeholderIcon: Icons.video_collection_outlined,
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
      coverUrl: collection.coverImage?.bestAvailableUrl,
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
  final String? coverUrl;
  final BoxFit coverFit;
  final IconData placeholderIcon;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return CollectionCoverCard(
      tapKey: tapKey,
      menuKey: menuKey,
      title: title,
      count: count,
      coverUrl: coverUrl,
      coverFit: coverFit,
      placeholderIcon: placeholderIcon,
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}
