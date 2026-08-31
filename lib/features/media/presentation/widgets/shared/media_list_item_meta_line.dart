import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/rapid_upload_status_badge.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';

/// 媒体列表行 / 移动端卡的共用元数据行。
///
/// 桌面 `_MediaMetaLine` 与移动 `_MobileMetaLine` 此前各写了一份几乎逐字相同的
/// badges（kind / 存储 / 库名 / 秒传状态）+ muted 数值（大小 / 时长 / 分辨率）
/// 组装逻辑，收口到这里。两端差异用参数表达：
/// - [spacing] / [runSpacing]：桌面 `sm / xs`，移动 `xs / xs`；
/// - [showZeroFileSize]：桌面显示 0 字节条目，移动端隐藏。
class MediaListItemMetaLine extends StatelessWidget {
  const MediaListItemMetaLine({
    super.key,
    required this.item,
    required this.storage,
    required this.spacing,
    required this.runSpacing,
    this.showZeroFileSize = true,
  });

  final MediaListItemDto item;
  final MediaStorageDescriptor storage;
  final double spacing;
  final double runSpacing;
  final bool showZeroFileSize;

  @override
  Widget build(BuildContext context) {
    final rapidUploadBadge = rapidUploadStatusBadge(item.lastRapidUploadStatus);
    final badges = <Widget>[
      AppBadge(
        label: item.kind.label,
        tone:
            item.kind == MediaListItemKind.jav
                ? AppBadgeTone.primary
                : AppBadgeTone.neutral,
        size: AppBadgeSize.compact,
      ),
      if (storage.isCloud115)
        const AppBadge(
          label: '115',
          tone: AppBadgeTone.info,
          size: AppBadgeSize.compact,
        )
      else if (storage.isLocal)
        const AppBadge(
          label: '本地',
          tone: AppBadgeTone.neutral,
          size: AppBadgeSize.compact,
        ),
      AppBadge(
        label: storage.formatLibraryText(libraryId: item.libraryId),
        tone: AppBadgeTone.neutral,
        size: AppBadgeSize.compact,
      ),
      if (rapidUploadBadge != null) rapidUploadBadge,
    ];
    final metrics = <String>[
      if (showZeroFileSize || item.fileSizeBytes > 0)
        formatFileSize(item.fileSizeBytes),
      if (item.durationSeconds > 0)
        formatMediaDurationLabel(item.durationSeconds),
      if (item.resolution != null && item.resolution!.isNotEmpty)
        item.resolution!,
    ];
    final mutedTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.muted,
    );
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...badges,
        for (final metric in metrics) Text(metric, style: mutedTextStyle),
      ],
    );
  }
}
