import 'package:flutter/material.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_cover_thumbnail.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_item_meta_line.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_item_path_line.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_check_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_left_cover_card.dart';

/// 移动端媒体卡：封面贴左（竖版 thin 图）+ 标题 / 元数据 / 路径。
///
/// 交互与桌面行不同：
/// - 非多选态：长按整卡进入多选态并选中该行；封面独立可点跳影片详情（JAV 项）；
/// - 多选态：整卡点击切换选中，封面不再跳转；选中行左上角叠 [SelectionCheckBadge]。
/// - 有禁选原因（秒传进行中）的行不响应长按与点选。
class MediaMobileListCard extends StatelessWidget {
  const MediaMobileListCard({
    super.key,
    required this.keyPrefix,
    required this.item,
    required this.storage,
    required this.isSelected,
    required this.selectionMode,
    required this.onLongPress,
    this.onToggleSelect,
    this.onOpenMovieDetail,
    this.disabledReason,
  });

  /// 测试 Key 前缀（移动端 `mobile-media-management`）。
  final String keyPrefix;

  final MediaListItemDto item;
  final MediaStorageDescriptor storage;
  final bool isSelected;
  final bool selectionMode;

  /// 非多选态长按：进入多选态；有禁选原因时调用方应传 null。
  final VoidCallback? onLongPress;

  /// 多选态整卡点选切换；`null` 表示该行不可选。
  final VoidCallback? onToggleSelect;

  /// 封面跳影片详情回调（JAV 项）；null 时封面纯图不可点。
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;

  /// 非空时行禁选：不响应长按/点选，挂 Tooltip 说明原因。
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;

    final coverWidth = componentTokens.mobileFollowMovieThinCoverWidth;
    final coverHeight = componentTokens.mobileFollowMovieCardHeight;

    final card = AppLeftCoverCard(
      key: Key('$keyPrefix-row-${item.id}'),
      coverWidth: coverWidth,
      bodyMinHeight: coverHeight,
      bodyPadding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      selected: selectionMode && isSelected,
      onTap: selectionMode ? onToggleSelect : null,
      cover: _MobileCoverSlot(
        keyPrefix: keyPrefix,
        item: item,
        coverWidth: coverWidth,
        coverHeight: coverHeight,
        selectionMode: selectionMode,
        isSelected: isSelected,
        onOpenMovieDetail: onOpenMovieDetail,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MobileHeadingLine(keyPrefix: keyPrefix, item: item),
          SizedBox(height: spacing.xs),
          MediaListItemMetaLine(
            item: item,
            storage: storage,
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            showZeroFileSize: false,
          ),
          if (item.path.isNotEmpty) ...[
            SizedBox(height: spacing.xs),
            MediaListItemPathLine(
              keyPrefix: keyPrefix,
              item: item,
              storage: storage,
            ),
          ],
        ],
      ),
    );

    Widget interactive = card;
    if (!selectionMode && onLongPress != null) {
      interactive = GestureDetector(
        key: Key('$keyPrefix-row-long-press-${item.id}'),
        behavior: HitTestBehavior.translucent,
        onLongPress: onLongPress,
        child: card,
      );
    }

    final reason = disabledReason;
    if (reason != null) {
      return Tooltip(message: reason, child: interactive);
    }
    return interactive;
  }
}

class _MobileCoverSlot extends StatelessWidget {
  const _MobileCoverSlot({
    required this.keyPrefix,
    required this.item,
    required this.coverWidth,
    required this.coverHeight,
    required this.selectionMode,
    required this.isSelected,
    this.onOpenMovieDetail,
  });

  final String keyPrefix;
  final MediaListItemDto item;
  final double coverWidth;
  final double coverHeight;
  final bool selectionMode;
  final bool isSelected;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;

  String? get _thinCoverUrl {
    final thinUrl = item.thinCoverImage?.bestAvailableUrl.trim();
    if (thinUrl != null && thinUrl.isNotEmpty) {
      return thinUrl;
    }
    final coverUrl = item.coverImage?.bestAvailableUrl.trim();
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return coverUrl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final url = _thinCoverUrl;
    final image = MediaCoverThumbnail(
      url: url,
      width: coverWidth,
      height: coverHeight,
      fit: BoxFit.cover,
      placeholderKey: Key('$keyPrefix-cover-placeholder-${item.id}'),
      imageKey: Key('$keyPrefix-cover-${item.id}'),
      placeholderBackground: context.appColors.surfaceMuted,
    );

    // 多选态：封面不跳转，仅叠勾选标记（点击由整卡接管）。
    if (selectionMode) {
      return Stack(
        fit: StackFit.expand,
        children: [
          image,
          Positioned(
            top: spacing.xs,
            left: spacing.xs,
            child: IgnorePointer(
              child: SelectionCheckBadge(isSelected: isSelected),
            ),
          ),
        ],
      );
    }

    // 非多选态：JAV 且有番号 → 封面独立可点跳影片详情；其余纯图。
    final movieNumber = item.movieNumber?.trim();
    final openMovieDetail = onOpenMovieDetail;
    if (!item.isJav || movieNumber == null || movieNumber.isEmpty) {
      return image;
    }
    if (openMovieDetail == null) {
      return image;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('$keyPrefix-cover-tap-${item.id}'),
        onTap: () => openMovieDetail(context, movieNumber),
        child: image,
      ),
    );
  }
}

class _MobileHeadingLine extends StatelessWidget {
  const _MobileHeadingLine({required this.keyPrefix, required this.item});

  final String keyPrefix;
  final MediaListItemDto item;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            item.displayHeading,
            key: Key('$keyPrefix-row-heading-${item.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
        ),
        if (!item.valid) ...[
          SizedBox(width: spacing.sm),
          const AppBadge(
            label: '失效',
            tone: AppBadgeTone.error,
            size: AppBadgeSize.compact,
          ),
        ],
      ],
    );
  }
}
