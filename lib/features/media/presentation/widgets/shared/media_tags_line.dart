import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';

/// 媒体文件的单行标签展示。
///
/// [maxTags] 为 null 时展示全部标签；超出上限时追加剩余数量徽标。
class MediaTagsLine extends StatelessWidget {
  const MediaTagsLine({
    super.key,
    required this.item,
    this.keyPrefix,
    this.maxTags,
  });

  final MediaListItemDto item;

  /// 组卡传入行级前缀；单条列表卡省略时保留原有 `{itemId}-media-tags` key。
  final String? keyPrefix;
  final int? maxTags;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visibleTags = maxTags == null
        ? item.tags
        : item.tags.take(maxTags!).toList(growable: false);
    final overflow = item.tags.length - visibleTags.length;
    final tagsKey = keyPrefix == null
        ? '${item.id}-media-tags'
        : '$keyPrefix-media-tags-${item.id}';
    return SingleChildScrollView(
      key: Key(tagsKey),
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
