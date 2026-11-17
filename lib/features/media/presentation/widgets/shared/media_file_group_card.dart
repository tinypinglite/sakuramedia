import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_cover_thumbnail.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_item_meta_label.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_item_technical_label.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_tags_line.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_left_cover_card.dart';

/// 「同一影片的多个文件」组卡：组头 + 组内文件行，整卡只有一层。
///
/// 组头是「贴边小缩略图 + 标题区 + chevron」的 [AppLeftCoverCard]（`shell: false`
/// 复用其贴边封面布局），缩略图由组卡圆角裁剪、与行卡封面区分层级；
/// 组内文件行前几行固定：第一行「文件名（超长省略，悬停/长按看全名）+ 附加信息
/// + 失效徽标」，第二行基础元数据，第三行技术摘要；JAV 文件若有标签或手工管理状态，再加一行
/// 可横向滚动的标签。行高不随文件名、附加信息或标签数量增长，不再各自成卡。
class MediaFileGroupCard extends ConsumerWidget {
  const MediaFileGroupCard({
    super.key,
    required this.items,
    required this.countLabel,
    required this.headerKey,
    required this.deleteLabel,
    this.itemSupplement,
    required this.keyPrefix,
    required this.mobile,
    this.onOpen,
    required this.onDelete,
    required this.selectedIds,
    required this.onToggle,
    this.statusLabel,
    this.footer,
  });

  final List<MediaListItemDto> items;
  final String countLabel;
  final Key headerKey;
  final String deleteLabel;

  /// 文件名行尾部的单行附加内容（差异番号、合集胶囊等）；由卡片限制为一行，
  /// 超出时横向滚动。
  final Widget? Function(MediaListItemDto)? itemSupplement;
  final String keyPrefix;
  final bool mobile;
  final VoidCallback? onOpen;
  final ValueChanged<MediaListItemDto> onDelete;
  final Set<int>? selectedIds;
  final ValueChanged<MediaListItemDto> onToggle;
  final String? statusLabel;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final movie = items.first;
    final selectionLimitReached =
        items.where((item) => selectedIds?.contains(item.id) ?? false).length >=
        items.length - 1;
    final libraries = ref.watch(mediaLibrariesProvider).value?.librariesById;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupHeader(
            movie: movie,
            countLabel: countLabel,
            headerKey: headerKey,
            keyPrefix: keyPrefix,
            mobile: mobile,
            onOpen: onOpen,
            statusLabel: statusLabel,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.md),
            child: Column(
              children: [
                for (var index = 0; index < items.length; index += 1) ...[
                  if (index > 0)
                    Divider(height: 1, thickness: 1, color: colors.divider),
                  _FileRow(
                    item: items[index],
                    library: libraries?[items[index].libraryId],
                    keyPrefix: keyPrefix,
                    deleteLabel: deleteLabel,
                    selectionLimitReached: selectionLimitReached,
                    selectedIds: selectedIds,
                    onToggle: onToggle,
                    onDelete: onDelete,
                    itemSupplement: itemSupplement?.call(items[index]),
                  ),
                ],
                if (footer != null) ...[
                  SizedBox(height: spacing.sm),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: footer!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.movie,
    required this.countLabel,
    required this.headerKey,
    required this.keyPrefix,
    required this.mobile,
    required this.onOpen,
    required this.statusLabel,
  });

  final MediaListItemDto movie;
  final String countLabel;
  final Key headerKey;
  final String keyPrefix;
  final bool mobile;
  final VoidCallback? onOpen;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final tokens = context.appComponentTokens;
    final width = tokens.listGroupHeaderCoverWidth;
    final height = tokens.listGroupHeaderCoverHeight;
    final subtitle = movie.displaySubtitle;
    return AppLeftCoverCard(
      key: headerKey,
      shell: false,
      coverWidth: width,
      bodyMinHeight: height,
      bodyPadding: EdgeInsets.all(mobile ? spacing.sm : spacing.md),
      onTap: onOpen,
      cover: MediaCoverThumbnail(
        url: mobile ? movie.preferredCoverUrl : movie.wideCoverUrl,
        imageKey: Key('$keyPrefix-cover-${movie.id}'),
        width: width,
        height: height,
        fit: mobile
            ? (movie.usesThinCover ? BoxFit.cover : BoxFit.contain)
            : (movie.hasWideCover ? BoxFit.cover : BoxFit.contain),
        placeholderBackground: colors.surfaceMuted,
      ),
      body: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  movie.displayHeading(AppLocalizations.of(context)),
                  key: Key('$keyPrefix-row-heading-${movie.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s16,
                    weight: AppTextWeight.semibold,
                    tone: AppTextTone.primary,
                  ),
                ),
                if (subtitle != null) ...[
                  SizedBox(height: spacing.xs / 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                ],
                SizedBox(height: spacing.sm),
                Wrap(
                  spacing: spacing.xs,
                  runSpacing: spacing.xs,
                  children: [
                    AppBadge(label: countLabel, tone: AppBadgeTone.neutral),
                    if (statusLabel != null)
                      AppStatusChip(
                        label: statusLabel!,
                        palette: AppStatusChipPalette.success(
                          icon: Icons.check_circle_outline,
                        ),
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (onOpen != null)
            Icon(
              Icons.chevron_right_rounded,
              color: context.appTextPalette.muted,
            ),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.item,
    required this.library,
    required this.keyPrefix,
    required this.deleteLabel,
    required this.selectionLimitReached,
    required this.selectedIds,
    required this.onToggle,
    required this.onDelete,
    required this.itemSupplement,
  });

  final MediaListItemDto item;
  final MediaLibraryDto? library;
  final String keyPrefix;
  final String deleteLabel;
  final bool selectionLimitReached;
  final Set<int>? selectedIds;
  final ValueChanged<MediaListItemDto> onToggle;
  final ValueChanged<MediaListItemDto> onDelete;
  final Widget? itemSupplement;

  bool get _selectable =>
      selectedIds == null ||
      (!selectionLimitReached || selectedIds!.contains(item.id));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final filenameStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s14,
      weight: AppTextWeight.medium,
      tone: AppTextTone.primary,
    );
    final technicalLabel = buildMediaListItemTechnicalLabel(item, l10n: l10n);
    return Material(
      color: Colors.transparent,
      child: AppInteractiveSurface(
        enabled: _selectable && selectedIds != null,
        key: Key('$keyPrefix-row-${item.id}'),
        onTap: selectedIds == null || !_selectable
            ? null
            : () => onToggle(item),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: IgnorePointer(
                  ignoring: selectedIds != null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (selectedIds != null) ...[
                        Tooltip(
                          message:
                              selectionLimitReached &&
                                  !selectedIds!.contains(item.id)
                              ? l10n.mediaListKeepAtLeastOne
                              : l10n.mediaListSelectItem,
                          child: Checkbox(
                            key: Key('$keyPrefix-select-${item.id}'),
                            value: selectedIds!.contains(item.id),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            onChanged:
                                selectionLimitReached &&
                                    !selectedIds!.contains(item.id)
                                ? null
                                : (_) => onToggle(item),
                          ),
                        ),
                        SizedBox(width: spacing.xs),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FileTitleLine(
                              item: item,
                              filenameStyle: filenameStyle,
                              keyPrefix: keyPrefix,
                              itemSupplement: itemSupplement,
                            ),
                            SizedBox(height: spacing.xs),
                            Text(
                              buildMediaListItemMetaLabel(
                                item,
                                l10n: l10n,
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
                            if (technicalLabel != null) ...[
                              SizedBox(height: spacing.xs),
                              Text(
                                technicalLabel,
                                key: Key('$keyPrefix-file-tech-${item.id}'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: resolveAppTextStyle(
                                  context,
                                  size: AppTextSize.s12,
                                  tone: AppTextTone.muted,
                                ),
                              ),
                            ],
                            if (item.isJav &&
                                (item.tags.isNotEmpty ||
                                    item.isMediaTagsManuallyManaged)) ...[
                              SizedBox(height: spacing.xs),
                              MediaTagsLine(item: item, keyPrefix: keyPrefix),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selectedIds == null) ...[
                SizedBox(width: spacing.sm),
                AppIconButton(
                  key: Key('$keyPrefix-delete-${item.id}'),
                  icon: const Icon(Icons.delete_outline_rounded),
                  size: AppIconButtonSize.compact,
                  iconColor: context.appTextPalette.error,
                  tooltip: deleteLabel,
                  semanticLabel: deleteLabel,
                  onPressed: () => onDelete(item),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 文件行的第一行：文件名（超长省略，Tooltip 看全名）+ 附加信息 + 失效徽标。
///
/// 附加信息被限制在行宽的 50% 内并横向滚动，保证整行恒为一行。
class _FileTitleLine extends StatelessWidget {
  const _FileTitleLine({
    required this.item,
    required this.filenameStyle,
    required this.keyPrefix,
    required this.itemSupplement,
  });

  final MediaListItemDto item;
  final TextStyle filenameStyle;
  final String keyPrefix;
  final Widget? itemSupplement;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return LayoutBuilder(
      builder: (context, constraints) {
        final supplement = itemSupplement;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Tooltip(
                message: item.fileName,
                child: Text(
                  item.fileName,
                  key: Key('$keyPrefix-file-${item.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: filenameStyle,
                ),
              ),
            ),
            if (supplement != null) ...[
              SizedBox(width: spacing.sm),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.5,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: supplement,
                ),
              ),
            ],
            if (!item.valid) ...[
              SizedBox(width: spacing.sm),
              AppStatusChip(
                label: AppLocalizations.of(context).mediaListInvalidBadge,
                palette: AppStatusChipPalette.error(
                  icon: Icons.broken_image_outlined,
                ),
                dense: true,
              ),
            ],
          ],
        );
      },
    );
  }
}
