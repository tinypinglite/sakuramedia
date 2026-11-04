import 'package:sakuramedia/core/format/media_technical.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 媒体行卡第二行技术摘要：`交错 · 编码 · 码率 · 帧率`。
///
/// 交错放在最前，窄屏省略时优先保留用户查看交错大小的诉求。
String? buildMediaListItemTechnicalLabel(
  MediaListItemDto item, {
  required AppLocalizations l10n,
}) {
  final info = item.technicalInfo;
  final parts = <String>[
    if (formatInterleaveGapSize(item.interleaveGapMib) case final gap?)
      l10n.mediaListMetaInterleave(gap),
    ?formatVideoCodecName(info?.codecName),
    ?formatVideoBitRate(info?.videoBitRate, info?.containerBitRate),
    ?formatVideoFrameRate(info?.frameRate),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
