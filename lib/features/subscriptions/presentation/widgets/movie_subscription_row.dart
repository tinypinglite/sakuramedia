import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/relative_time_label.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_list_item_dto.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_check_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_left_cover_card.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

class MovieSubscriptionRow extends StatelessWidget {
  const MovieSubscriptionRow({
    super.key,
    required this.item,
    required this.selectionMode,
    required this.isSelected,
    required this.isPending,
    required this.onTap,
    required this.onOpenDownloads,
    required this.onSearchMagnet,
    required this.onUnsubscribe,
  });

  final MovieSubscriptionListItemDto item;
  final bool selectionMode;
  final bool isSelected;
  final bool isPending;
  final VoidCallback onTap;
  final VoidCallback onOpenDownloads;
  final VoidCallback onSearchMagnet;
  final VoidCallback onUnsubscribe;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    return AppLeftCoverCard(
      key: Key('movie-subscription-row-${item.movieNumber}'),
      coverWidth: tokens.subscriptionRowCoverWidth,
      bodyMinHeight: tokens.subscriptionRowMinHeight,
      bodyPadding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      selected: selectionMode && isSelected,
      onTap: onTap,
      cover: _CoverSlot(
        item: item,
        selectionMode: selectionMode,
        isSelected: isSelected,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeadingLine(item: item),
          SizedBox(height: spacing.md),
          _SearchProgressLine(item: item),
          if (item.lastError?.isNotEmpty ?? false) ...[
            SizedBox(height: spacing.sm),
            _LastErrorLine(item: item, message: item.lastError!),
          ],
          SizedBox(height: spacing.sm),
          _FooterLine(
            item: item,
            selectionMode: selectionMode,
            isPending: isPending,
            onOpenDownloads: onOpenDownloads,
            onSearchMagnet: onSearchMagnet,
            onUnsubscribe: onUnsubscribe,
          ),
        ],
      ),
    );
  }
}

class _CoverSlot extends StatelessWidget {
  const _CoverSlot({
    required this.item,
    required this.selectionMode,
    required this.isSelected,
  });

  final MovieSubscriptionListItemDto item;
  final bool selectionMode;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final url = item.coverImage?.bestAvailableUrl.trim();
    final image = url != null && url.isNotEmpty
        ? MaskedImage(
            key: Key('movie-subscription-cover-${item.movieNumber}'),
            url: url,
            fit: BoxFit.cover,
          )
        : Container(
            key: Key('movie-subscription-cover-placeholder-${item.movieNumber}'),
            color: context.appColors.surfaceMuted,
            alignment: Alignment.center,
            child: Icon(
              Icons.movie_creation_outlined,
              size: context.appComponentTokens.iconSize2xl,
              color: context.appTextPalette.muted,
            ),
          );
    if (!selectionMode) return image;
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        PositionedDirectional(
          top: context.appSpacing.sm,
          start: context.appSpacing.sm,
          child: SelectionCheckBadge(isSelected: isSelected),
        ),
      ],
    );
  }
}

class _HeadingLine extends StatelessWidget {
  const _HeadingLine({required this.item});

  final MovieSubscriptionListItemDto item;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.movieNumber,
                key: Key('movie-subscription-row-number-${item.movieNumber}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                item.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: spacing.sm),
        AppBadge(
          key: Key('movie-subscription-row-status-${item.movieNumber}'),
          label: item.displayStatusLabel,
          tone: _statusBadgeTone(item.status),
          size: AppBadgeSize.compact,
        ),
      ],
    );
  }
}

AppBadgeTone _statusBadgeTone(MovieSubscriptionStatus status) => switch (status) {
  MovieSubscriptionStatus.imported => AppBadgeTone.success,
  MovieSubscriptionStatus.importFailed => AppBadgeTone.error,
  MovieSubscriptionStatus.downloading => AppBadgeTone.info,
  MovieSubscriptionStatus.exhausted => AppBadgeTone.warning,
  MovieSubscriptionStatus.failed => AppBadgeTone.error,
  MovieSubscriptionStatus.missing => AppBadgeTone.neutral,
  MovieSubscriptionStatus.pending => AppBadgeTone.info,
  MovieSubscriptionStatus.unknown => AppBadgeTone.neutral,
};

class _SearchProgressLine extends StatelessWidget {
  const _SearchProgressLine({required this.item});

  final MovieSubscriptionListItemDto item;

  @override
  Widget build(BuildContext context) {
    final style = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    );
    final showProgress = switch (item.status) {
      MovieSubscriptionStatus.pending ||
      MovieSubscriptionStatus.missing ||
      MovieSubscriptionStatus.failed ||
      MovieSubscriptionStatus.exhausted => true,
      _ => false,
    };
    return Wrap(
      spacing: context.appSpacing.sm,
      runSpacing: context.appSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showProgress) ...[
          if (item.isFresh)
            Text('新片 · 持续查询中', style: style)
          else if (item.status == MovieSubscriptionStatus.exhausted)
            Text('已查询过 ${item.attemptCount} 次', style: style)
          else if (item.attemptCount > 0 && item.attemptCount < item.attemptLimit)
            Text('再尝试 ${item.attemptLimit - item.attemptCount} 次就放弃', style: style),
          Text(
            item.lastSearchedAt == null
                ? '尚未查询'
                : formatRelativeTimeLabel(item.lastSearchedAt!, suffix: '查过'),
            style: style,
          ),
        ],
        if (item.deadDownloadTaskCount > 0)
          AppBadge(
            key: Key('movie-subscription-row-dead-${item.movieNumber}'),
            label: '${item.deadDownloadTaskCount} 个种子已判死',
            tone: AppBadgeTone.warning,
            size: AppBadgeSize.compact,
          ),
      ],
    );
  }
}

class _LastErrorLine extends StatelessWidget {
  const _LastErrorLine({required this.item, required this.message});

  final MovieSubscriptionListItemDto item;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: context.appComponentTokens.iconSize3xs,
            color: context.appTextPalette.error,
          ),
          SizedBox(width: context.appSpacing.xs),
          Expanded(
            child: Text(
              message,
              key: Key('movie-subscription-row-error-${item.movieNumber}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterLine extends StatelessWidget {
  const _FooterLine({
    required this.item,
    required this.selectionMode,
    required this.isPending,
    required this.onOpenDownloads,
    required this.onSearchMagnet,
    required this.onUnsubscribe,
  });

  final MovieSubscriptionListItemDto item;
  final bool selectionMode;
  final bool isPending;
  final VoidCallback onOpenDownloads;
  final VoidCallback onSearchMagnet;
  final VoidCallback onUnsubscribe;

  @override
  Widget build(BuildContext context) {
    final facts = <String>[
      if (item.releaseDate != null) '发行 ${item.releaseDate}',
      if (item.subscribedAt != null)
        formatRelativeTimeLabel(item.subscribedAt!, suffix: '订阅'),
      if (item.mediaCount > 0) '本地 ${item.mediaCount} 个媒体',
    ];
    final mutedStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    );
    return Row(
      children: [
        Icon(
          Icons.event_outlined,
          size: context.appComponentTokens.iconSize3xs,
          color: context.appTextPalette.muted,
        ),
        SizedBox(width: context.appSpacing.xs),
        Expanded(
          child: Text(
            facts.isEmpty ? '暂无发行与订阅信息' : facts.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mutedStyle,
          ),
        ),
        if (!selectionMode) ...[
          SizedBox(width: context.appSpacing.sm),
          if (isPending)
            const AppInlineSpinner()
          else
            _RowActions(
              onOpenDownloads: onOpenDownloads,
              onSearchMagnet: onSearchMagnet,
              onUnsubscribe: onUnsubscribe,
            ),
        ],
      ],
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.onOpenDownloads,
    required this.onSearchMagnet,
    required this.onUnsubscribe,
  });

  final VoidCallback onOpenDownloads;
  final VoidCallback onSearchMagnet;
  final VoidCallback onUnsubscribe;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIconButton(
          key: const Key('movie-subscription-row-downloads'),
          icon: const Icon(Icons.download_outlined),
          size: AppIconButtonSize.regular,
          tooltip: '查看下载任务',
          semanticLabel: '查看下载任务',
          onPressed: onOpenDownloads,
        ),
        AppIconButton(
          key: const Key('movie-subscription-row-magnet-search'),
          icon: const Icon(Icons.search_rounded),
          size: AppIconButtonSize.regular,
          tooltip: '磁力搜索',
          semanticLabel: '磁力搜索',
          onPressed: onSearchMagnet,
        ),
        AppIconButton(
          key: const Key('movie-subscription-row-unsubscribe'),
          icon: const Icon(Icons.bookmark_remove_outlined),
          size: AppIconButtonSize.regular,
          tooltip: '取消订阅',
          semanticLabel: '取消订阅',
          onPressed: onUnsubscribe,
        ),
      ],
    );
  }
}
