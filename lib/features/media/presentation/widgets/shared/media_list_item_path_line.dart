import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

/// 媒体列表行 / 移动端卡的共用文件名行：folder icon + 文件名 muted（省略号）。
///
/// 桌面 `_MediaPathLine` 与移动 `_MobilePathLine` 此前各写了一份同构实现；
/// 收口到这里，差异仅桌面额外显示「更新 …」后缀（[showUpdatedAt]）。
class MediaListItemPathLine extends StatelessWidget {
  const MediaListItemPathLine({
    super.key,
    required this.keyPrefix,
    required this.item,
    this.showUpdatedAt = false,
    this.trailing,
  });

  final String keyPrefix;
  final MediaListItemDto item;
  final bool showUpdatedAt;

  /// 行尾动作（如媒体卡的行内「重试缩略图」）。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final mutedTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    );
    final updatedLabel = showUpdatedAt && item.updatedAt != null
        ? formatUpdatedAtLabel(item.updatedAt)
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.folder_open_outlined,
          size: context.appComponentTokens.iconSize3xs,
          color: context.appTextPalette.muted,
        ),
        SizedBox(width: spacing.xs),
        Expanded(
          child: Text(
            item.fileName,
            key: Key('$keyPrefix-row-path-${item.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mutedTextStyle,
          ),
        ),
        if (updatedLabel != null) ...[
          SizedBox(width: spacing.md),
          // 不用 Flexible：否则会和文件名行的 Expanded 平分剩余空间，
          // 把行尾动作顶不到最右边（末尾留一段空白）。
          Text(
            AppLocalizations.of(context).mediaListUpdatedAt(updatedLabel),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mutedTextStyle,
          ),
        ],
        if (trailing != null) ...[SizedBox(width: spacing.sm), trailing!],
      ],
    );
  }
}
