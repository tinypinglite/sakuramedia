import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/app_date_format.dart';
import 'package:sakuramedia/core/format/relative_time_label.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_list_item_dto.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';
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
    this.onDeleteDownloads,
    this.onViewFiles,
    this.onRetriggerImport,
    this.isRetriggering = false,
    this.onOpenActions,
    required this.mobile,
  });

  final MovieSubscriptionListItemDto item;
  final bool selectionMode;
  final bool isSelected;
  final bool isPending;
  final VoidCallback onTap;
  final VoidCallback? onOpenDownloads;
  final VoidCallback onSearchMagnet;
  final VoidCallback onUnsubscribe;
  final VoidCallback? onDeleteDownloads;
  final VoidCallback? onViewFiles;
  final VoidCallback? onRetriggerImport;
  final bool isRetriggering;

  /// 移动端「更多操作」入口：打开底部操作表；桌面端仍用行内图标。
  final VoidCallback? onOpenActions;

  /// 移动端布局：操作收进「更多」按钮，具体动作放底部操作表。
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final l10n = AppLocalizations.of(context);
    return AppLeftCoverCard(
      key: Key('movie-subscription-row-${item.movieNumber}'),
      coverWidth: tokens.listRowCoverWidth,
      bodyMinHeight: tokens.listRowCoverHeight,
      bodyPadding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      selected: selectionMode && isSelected,
      onTap: onTap,
      cover: _CoverSlot(
        item: item,
        mobile: mobile,
        selectionMode: selectionMode,
        isSelected: isSelected,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeadingLine(item: item),
          SizedBox(height: spacing.md),
          _SearchProgressLine(item: item),
          if (item.status == MovieSubscriptionStatus.importFailed &&
              item.importStatusLabel?.isNotEmpty == true) ...[
            SizedBox(height: spacing.sm),
            _LastErrorLine(
              item: item,
              message: item.isImportedMediaRemoved
                  ? l10n.subscriptionImportMediaRemovedHint
                  : l10n.subscriptionImportStatusHint(item.importStatusLabel!),
              keySuffix: 'import-hint',
            ),
          ],
          if (item.lastError?.isNotEmpty ?? false) ...[
            SizedBox(height: spacing.sm),
            _LastErrorLine(item: item, message: item.lastError!),
          ],
          SizedBox(height: spacing.sm),
          _FooterLine(
            item: item,
            selectionMode: selectionMode,
            isPending: isPending,
            mobile: mobile,
            onOpenDownloads: onOpenDownloads,
            onViewFiles: onViewFiles,
            onRetriggerImport: onRetriggerImport,
            isRetriggering: isRetriggering,
            onOpenActions: onOpenActions,
            onSearchMagnet: onSearchMagnet,
            onUnsubscribe: onUnsubscribe,
            onDeleteDownloads: onDeleteDownloads,
          ),
        ],
      ),
    );
  }
}

class _CoverSlot extends StatelessWidget {
  const _CoverSlot({
    required this.item,
    required this.mobile,
    required this.selectionMode,
    required this.isSelected,
  });

  final MovieSubscriptionListItemDto item;
  final bool mobile;
  final bool selectionMode;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final url = mobile ? item.preferredCoverUrl : item.wideCoverUrl;
    // 窄框用窄图、宽框用宽图才裁切；回退到另一方向的图时居中留边。
    final fit = mobile
        ? (item.usesThinCover ? BoxFit.cover : BoxFit.contain)
        : (item.hasWideCover ? BoxFit.cover : BoxFit.contain);
    final image = url != null && url.isNotEmpty
        ? MaskedImage(
            key: Key('movie-subscription-cover-${item.movieNumber}'),
            url: url,
            fit: fit,
          )
        : Container(
            key: Key(
              'movie-subscription-cover-placeholder-${item.movieNumber}',
            ),
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
        AppStatusChip(
          key: Key('movie-subscription-row-status-${item.movieNumber}'),
          label: item.displayStatusLabel(AppLocalizations.of(context)),
          palette: _statusPalette(item),
          dense: true,
        ),
      ],
    );
  }
}

AppStatusChipPalette _statusPalette(MovieSubscriptionListItemDto item) {
  if (item.isImportedMediaRemoved) {
    return AppStatusChipPalette.muted(icon: Icons.link_off_rounded);
  }
  return switch (item.status) {
    MovieSubscriptionStatus.imported => AppStatusChipPalette.success(),
    MovieSubscriptionStatus.importFailed => AppStatusChipPalette.error(),
    MovieSubscriptionStatus.downloading => AppStatusChipPalette.info(
      icon: Icons.download_outlined,
    ),
    MovieSubscriptionStatus.exhausted => AppStatusChipPalette.warning(
      icon: Icons.search_off_rounded,
    ),
    MovieSubscriptionStatus.failed => AppStatusChipPalette.error(),
    MovieSubscriptionStatus.missing => AppStatusChipPalette.neutral(
      icon: Icons.search_rounded,
    ),
    MovieSubscriptionStatus.pending => AppStatusChipPalette.forSemantic(
      AppStatusSemantic.queued,
    ),
    MovieSubscriptionStatus.unknown => AppStatusChipPalette.neutral(
      icon: Icons.help_outline_rounded,
    ),
  };
}

class _SearchProgressLine extends StatelessWidget {
  const _SearchProgressLine({required this.item});

  final MovieSubscriptionListItemDto item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            Text(l10n.subscriptionNewMovieSearching, style: style)
          else if (item.status == MovieSubscriptionStatus.exhausted)
            Text(
              l10n.subscriptionSearchedTimes(item.attemptCount),
              style: style,
            )
          else if (item.attemptCount > 0 &&
              item.attemptCount < item.attemptLimit)
            Text(
              l10n.subscriptionRetryBeforeGivingUp(
                item.attemptLimit - item.attemptCount,
              ),
              style: style,
            ),
          Text(
            item.lastSearchedAt == null
                ? l10n.subscriptionNotSearched
                : l10n.subscriptionLastSearchedAt(
                    formatRelativeTimeLabel(item.lastSearchedAt!, l10n: l10n),
                  ),
            style: style,
          ),
        ],
        if (item.deadDownloadTaskCount > 0)
          AppBadge(
            key: Key('movie-subscription-row-dead-${item.movieNumber}'),
            label: l10n.subscriptionDeadTorrents(item.deadDownloadTaskCount),
            tone: AppBadgeTone.warning,
            size: AppBadgeSize.compact,
          ),
      ],
    );
  }
}

class _LastErrorLine extends StatelessWidget {
  const _LastErrorLine({
    required this.item,
    required this.message,
    this.keySuffix = 'error',
  });

  final MovieSubscriptionListItemDto item;
  final String message;
  final String keySuffix;

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
              key: Key('movie-subscription-row-$keySuffix-${item.movieNumber}'),
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
    required this.mobile,
    required this.onOpenDownloads,
    required this.onSearchMagnet,
    required this.onUnsubscribe,
    this.onDeleteDownloads,
    this.onViewFiles,
    this.onRetriggerImport,
    this.isRetriggering = false,
    this.onOpenActions,
  });

  final MovieSubscriptionListItemDto item;
  final bool selectionMode;
  final bool isPending;
  final bool mobile;
  final VoidCallback? onOpenDownloads;
  final VoidCallback onSearchMagnet;
  final VoidCallback onUnsubscribe;
  final VoidCallback? onDeleteDownloads;
  final VoidCallback? onViewFiles;
  final VoidCallback? onRetriggerImport;
  final bool isRetriggering;
  final VoidCallback? onOpenActions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final facts = <String>[
      if (item.releaseDate != null)
        l10n.subscriptionReleasedAt(formatAppDate(item.releaseDate!)),
      if (item.subscribedAt != null)
        l10n.subscriptionSubscribedAt(
          formatRelativeTimeLabel(item.subscribedAt!, l10n: l10n),
        ),
      if (item.mediaCount > 0)
        l10n.subscriptionLocalMediaCount(item.mediaCount),
    ];
    final mutedStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    );
    final factsLine = Row(
      children: [
        Icon(
          Icons.event_outlined,
          size: context.appComponentTokens.iconSize3xs,
          color: context.appTextPalette.muted,
        ),
        SizedBox(width: context.appSpacing.xs),
        Expanded(
          child: Text(
            facts.isEmpty
                ? l10n.subscriptionRowNoReleaseInfo
                : facts.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mutedStyle,
          ),
        ),
      ],
    );
    // 移动端卡片窄（封面 116），操作图标和 facts 同行会把文字挤没；操作收进
    // 一个「更多」按钮，具体动作放底部操作表（带中文标签），不让用户猜图标。
    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          factsLine,
          if (!selectionMode) ...[
            SizedBox(height: context.appSpacing.sm),
            if (isPending)
              const Align(
                alignment: Alignment.centerRight,
                child: AppInlineSpinner(),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: AppIconButton(
                  key: const Key('movie-subscription-row-more'),
                  icon: const Icon(Icons.more_horiz_rounded),
                  size: AppIconButtonSize.compact,
                  tooltip: l10n.subscriptionRowMoreActions,
                  semanticLabel: l10n.subscriptionRowMoreActions,
                  onPressed: onOpenActions,
                ),
              ),
          ],
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: factsLine),
        if (!selectionMode) ...[
          SizedBox(width: context.appSpacing.sm),
          if (isPending)
            const AppInlineSpinner()
          else
            _RowActions(
              onOpenDownloads: onOpenDownloads,
              onViewFiles: onViewFiles,
              onRetriggerImport: onRetriggerImport,
              isRetriggering: isRetriggering,
              onSearchMagnet: onSearchMagnet,
              onUnsubscribe: onUnsubscribe,
              onDeleteDownloads: onDeleteDownloads,
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
    this.onDeleteDownloads,
    this.onViewFiles,
    this.onRetriggerImport,
    this.isRetriggering = false,
  });

  final VoidCallback? onOpenDownloads;
  final VoidCallback onSearchMagnet;
  final VoidCallback onUnsubscribe;
  final VoidCallback? onDeleteDownloads;
  final VoidCallback? onViewFiles;
  final VoidCallback? onRetriggerImport;
  final bool isRetriggering;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onOpenDownloads != null)
          AppIconButton(
            key: const Key('movie-subscription-row-downloads'),
            icon: const Icon(Icons.download_outlined),
            size: AppIconButtonSize.compact,
            tooltip: l10n.subscriptionActionViewDownloads,
            semanticLabel: l10n.subscriptionActionViewDownloads,
            onPressed: onOpenDownloads,
          ),
        if (onViewFiles != null)
          AppIconButton(
            key: const Key('movie-subscription-row-files'),
            icon: const Icon(Icons.folder_open_rounded),
            size: AppIconButtonSize.compact,
            tooltip: l10n.subscriptionActionViewFiles,
            semanticLabel: l10n.subscriptionActionViewFiles,
            onPressed: onViewFiles,
          ),
        if (onRetriggerImport != null)
          AppIconButton(
            key: const Key('movie-subscription-row-retrigger-import'),
            icon: const Icon(Icons.refresh_rounded),
            size: AppIconButtonSize.compact,
            tooltip: l10n.subscriptionActionRetriggerImport,
            semanticLabel: l10n.subscriptionActionRetriggerImport,
            onPressed: isRetriggering ? null : onRetriggerImport,
          ),
        AppIconButton(
          key: const Key('movie-subscription-row-magnet-search'),
          icon: const Icon(Icons.search_rounded),
          size: AppIconButtonSize.compact,
          tooltip: l10n.subscriptionActionSearchMagnet,
          semanticLabel: l10n.subscriptionActionSearchMagnet,
          onPressed: onSearchMagnet,
        ),
        if (onDeleteDownloads != null)
          AppIconButton(
            key: const Key('movie-subscription-row-delete-downloads'),
            icon: const Icon(Icons.delete_outline_rounded),
            size: AppIconButtonSize.compact,
            tooltip: l10n.subscriptionActionDeleteDownloads,
            semanticLabel: l10n.subscriptionActionDeleteDownloads,
            onPressed: onDeleteDownloads,
          ),
        AppIconButton(
          key: const Key('movie-subscription-row-unsubscribe'),
          icon: const Icon(Icons.bookmark_remove_outlined),
          size: AppIconButtonSize.compact,
          tooltip: l10n.subscriptionActionUnsubscribe,
          semanticLabel: l10n.subscriptionActionUnsubscribe,
          onPressed: onUnsubscribe,
        ),
      ],
    );
  }
}
