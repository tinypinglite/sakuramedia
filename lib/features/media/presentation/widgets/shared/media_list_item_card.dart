import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_cover_thumbnail.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_item_meta_label.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_item_path_line.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_left_cover_card.dart';

/// 单条媒体的统一展示卡，供媒体列表和媒体维护列表复用。
///
/// 版式对齐订阅管理行卡（[AppLeftCoverCard]）：`[封面 | 内容]`。
/// 封面贴左整高、由卡片圆角裁剪，桌面用宽图（16:9）、移动用窄竖图；
/// 卡片只有一层（白底、细边、无阴影），选中只换边框色。
///
/// 单项「删除 / 迁移 / 重试缩略图」：桌面端平铺图标动作（hover 有 tooltip）；
/// 移动端收进卡片右下角的「更多」按钮，动作放带中文标签的底部操作表
/// （对齐订阅管理行卡），避免无标签图标让用户猜。
class MediaListItemCard extends StatelessWidget {
  const MediaListItemCard({
    super.key,
    required this.keyPrefix,
    required this.item,
    required this.mobile,
    this.library,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.isDeleting = false,
    this.canDelete = true,
    this.onTransfer,
    this.isTransferring = false,
    this.canTransfer = true,
    this.onRetryThumbnails,
    this.isRetryingThumbnails = false,
    this.canRetryThumbnails = true,
    this.retryThumbnailsLabel,
    this.onOpenActions,
    this.onEditTags,
    this.showUpdatedAt = false,
  });

  final String keyPrefix;
  final MediaListItemDto item;
  final bool mobile;
  final MediaLibraryDto? library;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final bool isDeleting;
  final bool canDelete;
  final VoidCallback? onTransfer;
  final bool isTransferring;
  final bool canTransfer;
  final VoidCallback? onRetryThumbnails;
  final bool isRetryingThumbnails;
  final bool canRetryThumbnails;

  /// 缩略图重试 / 重新生成的动作文案；不传时用当前语言的默认「重试缩略图」。
  final String? retryThumbnailsLabel;

  /// 移动端「更多」入口：为 null 时不显示（选择态、无可用动作）。
  final VoidCallback? onOpenActions;
  final VoidCallback? onEditTags;
  final bool showUpdatedAt;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final width = tokens.listRowCoverWidth;
    final height = tokens.listRowCoverHeight;

    final card = AppLeftCoverCard(
      key: Key('$keyPrefix-row-${item.id}'),
      coverWidth: width,
      bodyMinHeight: height,
      bodyPadding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      selected: selected,
      onTap: onTap,
      onLongPress: mobile ? onLongPress : null,
      cover: _MediaListItemCover(
        keyPrefix: keyPrefix,
        item: item,
        mobile: mobile,
        width: width,
        height: height,
      ),
      body: _MediaListItemBody(
        keyPrefix: keyPrefix,
        item: item,
        library: library,
        mobile: mobile,
        onDelete: onDelete,
        isDeleting: isDeleting,
        canDelete: canDelete,
        onTransfer: onTransfer,
        isTransferring: isTransferring,
        canTransfer: canTransfer,
        onRetryThumbnails: onRetryThumbnails,
        isRetryingThumbnails: isRetryingThumbnails,
        canRetryThumbnails: canRetryThumbnails,
        retryThumbnailsLabel: retryThumbnailsLabel,
        onOpenActions: onOpenActions,
        onEditTags: onEditTags,
        showUpdatedAt: showUpdatedAt,
      ),
    );

    return card;
  }
}

class _MediaListItemBody extends StatelessWidget {
  const _MediaListItemBody({
    required this.keyPrefix,
    required this.item,
    required this.library,
    required this.mobile,
    required this.onDelete,
    required this.isDeleting,
    required this.canDelete,
    required this.onTransfer,
    required this.isTransferring,
    required this.canTransfer,
    required this.onRetryThumbnails,
    required this.isRetryingThumbnails,
    required this.canRetryThumbnails,
    required this.retryThumbnailsLabel,
    required this.onOpenActions,
    required this.onEditTags,
    required this.showUpdatedAt,
  });

  final String keyPrefix;
  final MediaListItemDto item;
  final MediaLibraryDto? library;
  final bool mobile;
  final VoidCallback? onDelete;
  final bool isDeleting;
  final bool canDelete;
  final VoidCallback? onTransfer;
  final bool isTransferring;
  final bool canTransfer;
  final VoidCallback? onRetryThumbnails;
  final bool isRetryingThumbnails;
  final bool canRetryThumbnails;
  final String? retryThumbnailsLabel;
  final VoidCallback? onOpenActions;
  final VoidCallback? onEditTags;
  final bool showUpdatedAt;

  /// 缩略图重试 / 重新生成：平铺图标动作；执行中换成小转圈。
  Widget? _retryAction(BuildContext context, AppLocalizations l10n) {
    final retry = onRetryThumbnails;
    if (retry == null) {
      return null;
    }
    if (isRetryingThumbnails) {
      return const AppInlineSpinner();
    }
    final label = retryThumbnailsLabel ?? l10n.mediaListActionRetryThumbnails;
    return AppIconButton(
      key: Key('$keyPrefix-retry-thumbnails-${item.id}'),
      icon: const Icon(Icons.refresh_rounded),
      tooltip: label,
      semanticLabel: label,
      onPressed: canRetryThumbnails ? retry : null,
    );
  }

  /// 行操作（平铺图标）：行内「重试缩略图」+「迁移」+「删除」。
  Widget? _actions(BuildContext context, Widget? retry, AppLocalizations l10n) {
    final spacing = context.appSpacing;
    final widgets = <Widget>[];
    if (onEditTags != null) {
      widgets.add(
        AppIconButton(
          key: Key('$keyPrefix-edit-tags-${item.id}'),
          icon: const Icon(Icons.sell_outlined),
          tooltip: l10n.mediaListTagsEdit,
          semanticLabel: l10n.mediaListTagsEdit,
          onPressed: onEditTags,
        ),
      );
    }
    if (retry != null) {
      widgets.add(retry);
    }
    if (onTransfer != null) {
      widgets.add(
        isTransferring
            ? const AppInlineSpinner()
            : AppIconButton(
                key: Key('$keyPrefix-transfer-${item.id}'),
                icon: const Icon(Icons.drive_file_move_outline),
                tooltip: l10n.mediaListActionTransfer,
                semanticLabel: l10n.mediaListActionTransferToLibrary,
                onPressed: canTransfer ? onTransfer : null,
              ),
      );
    }
    if (onDelete != null) {
      widgets.add(
        isDeleting
            ? const AppInlineSpinner()
            : AppIconButton(
                key: Key('$keyPrefix-delete-${item.id}'),
                icon: const Icon(Icons.delete_outline_rounded),
                iconColor: context.appTextPalette.error,
                tooltip: l10n.commonDelete,
                semanticLabel: l10n.commonDelete,
                onPressed: canDelete ? onDelete : null,
              ),
      );
    }
    if (widgets.isEmpty) {
      return null;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < widgets.length; index += 1) ...[
          if (index > 0) SizedBox(width: spacing.xs),
          widgets[index],
        ],
      ],
    );
  }

  /// 移动端「更多」：桌面端那排无标签图标收进底部操作表；执行中换成小转圈。
  ///
  /// 只有传入了 [onOpenActions] 才启用（媒体管理列表）；单动作场景（如失效媒体
  /// 列表只有一个删除）没有操作表，继续沿用平铺图标。
  ///
  /// 全局忙（其它条目正在删除 / 迁移 / 重置）时三类动作都不可用，入口与桌面端
  /// 被禁用的行内图标一致置灰，避免打开一张所有动作都点不动的操作表。
  Widget _mobileActions(AppLocalizations l10n) {
    if (isDeleting || isTransferring || isRetryingThumbnails) {
      return const AppInlineSpinner();
    }
    final hasAvailableAction =
        (onRetryThumbnails != null && canRetryThumbnails) ||
        onEditTags != null ||
        canDelete ||
        canTransfer;
    return AppIconButton(
      key: Key('$keyPrefix-row-actions-${item.id}'),
      icon: const Icon(Icons.more_horiz_rounded),
      size: AppIconButtonSize.compact,
      tooltip: l10n.mediaListActionMore,
      semanticLabel: l10n.mediaListActionMore,
      onPressed: hasAvailableAction ? onOpenActions : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final subtitle = item.displaySubtitle;
    final retryAction = _retryAction(context, l10n);
    final actions = mobile && onOpenActions != null
        ? _mobileActions(l10n)
        : _actions(context, retryAction, l10n);
    final pathLine = MediaListItemPathLine(
      keyPrefix: keyPrefix,
      item: item,
      showUpdatedAt: showUpdatedAt,
      trailing: mobile ? null : actions,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _MediaListItemHeading(keyPrefix: keyPrefix, item: item),
        if (subtitle != null) ...[
          SizedBox(height: spacing.xs),
          Text(
            subtitle,
            maxLines: mobile ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
        ],
        SizedBox(height: spacing.sm),
        Text(
          buildMediaListItemMetaLabel(
            item,
            l10n: AppLocalizations.of(context),
            library: library,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
        if (item.isJav &&
            (item.tags.isNotEmpty || item.isMediaTagsManuallyManaged)) ...[
          SizedBox(height: spacing.xs),
          _MediaTagsLine(item: item),
        ],
        SizedBox(height: spacing.xs),
        pathLine,
        if (mobile && actions != null) ...[
          SizedBox(height: spacing.sm),
          Align(alignment: AlignmentDirectional.centerEnd, child: actions),
        ],
      ],
    );
  }
}

class _MediaListItemCover extends StatelessWidget {
  const _MediaListItemCover({
    required this.keyPrefix,
    required this.item,
    required this.mobile,
    required this.width,
    required this.height,
  });

  final String keyPrefix;
  final MediaListItemDto item;
  final bool mobile;
  final double width;
  final double height;

  /// 桌面用宽图（16:9），移动用窄图。
  String? get _coverUrl => mobile ? item.preferredCoverUrl : item.wideCoverUrl;

  /// 用图与框方向一致才裁切（cover）；回退到另一方向的图时改居中留边（contain）。
  BoxFit get _coverFit {
    if (mobile) {
      return item.usesThinCover ? BoxFit.cover : BoxFit.contain;
    }
    return item.hasWideCover ? BoxFit.cover : BoxFit.contain;
  }

  @override
  Widget build(BuildContext context) {
    return MediaCoverThumbnail(
      url: _coverUrl,
      width: width,
      height: height,
      fit: _coverFit,
      placeholderKey: Key('$keyPrefix-cover-placeholder-${item.id}'),
      imageKey: Key('$keyPrefix-cover-${item.id}'),
      placeholderBackground: context.appColors.surfaceMuted,
    );
  }
}

class _MediaListItemHeading extends StatelessWidget {
  const _MediaListItemHeading({required this.keyPrefix, required this.item});

  final String keyPrefix;
  final MediaListItemDto item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return Row(
      children: [
        Flexible(
          child: Text(
            item.displayHeading(l10n),
            key: Key('$keyPrefix-row-heading-${item.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
        ),
        // JAV 是绝大多数，徽标只在「视频归属」这类非默认情况出现；
        // 「未知归属」没有信息量，也不出徽标。
        if (item.kind == MediaListItemKind.video) ...[
          SizedBox(width: spacing.sm),
          AppBadge(
            label: item.kind.labelWith(l10n: l10n),
            tone: AppBadgeTone.neutral,
            size: AppBadgeSize.compact,
          ),
        ],
        if (!item.valid) ...[
          SizedBox(width: spacing.sm),
          AppBadge(
            label: l10n.mediaListInvalidBadge,
            tone: AppBadgeTone.error,
            size: AppBadgeSize.compact,
          ),
        ],
      ],
    );
  }
}

class _MediaTagsLine extends StatelessWidget {
  const _MediaTagsLine({required this.item});

  final MediaListItemDto item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visibleTags = item.tags.take(3).toList(growable: false);
    final overflow = item.tags.length - visibleTags.length;
    return SingleChildScrollView(
      key: Key('${item.id}-media-tags'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (item.isMediaTagsManuallyManaged)
            Padding(
              padding: EdgeInsetsDirectional.only(end: context.appSpacing.xs),
              child: AppBadge(
                label: l10n.mediaListTagsManualBadge,
                tone: AppBadgeTone.primary,
                size: AppBadgeSize.compact,
              ),
            ),
          for (final tag in visibleTags)
            Padding(
              padding: EdgeInsetsDirectional.only(end: context.appSpacing.xs),
              child: AppBadge(
                label: tag.name,
                tone: AppBadgeTone.neutral,
                size: AppBadgeSize.compact,
              ),
            ),
          if (overflow > 0)
            AppBadge(
              label: l10n.mediaListTagsOverflow(overflow),
              tone: AppBadgeTone.neutral,
              size: AppBadgeSize.compact,
            ),
        ],
      ),
    );
  }
}
