import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/theme.dart';

/// 媒体列表行 / 移动端卡的共用路径行：folder icon + 相对路径 muted（省略号）。
///
/// 桌面 `_MediaPathLine` 与移动 `_MobilePathLine` 此前各写了一份同构实现；
/// 收口到这里，差异仅桌面额外显示「更新 …」后缀（[showUpdatedAt]）。
class MediaListItemPathLine extends StatelessWidget {
  const MediaListItemPathLine({
    super.key,
    required this.keyPrefix,
    required this.item,
    required this.storage,
    this.showUpdatedAt = false,
  });

  final String keyPrefix;
  final MediaListItemDto item;
  final MediaStorageDescriptor storage;
  final bool showUpdatedAt;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final mutedTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    );
    final updatedLabel =
        showUpdatedAt && item.updatedAt != null
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
            storage.formatLocationText(item.path),
            key: Key('$keyPrefix-row-path-${item.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mutedTextStyle,
          ),
        ),
        if (updatedLabel != null) ...[
          SizedBox(width: spacing.md),
          Text('更新 $updatedLabel', style: mutedTextStyle),
        ],
      ],
    );
  }
}
