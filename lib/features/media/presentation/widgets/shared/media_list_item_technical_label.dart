import 'package:sakuramedia/core/format/media_technical.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 媒体行卡第二行技术摘要：`编码 · 码率 · 帧率`。
String? buildMediaListItemTechnicalLabel(
  MediaListItemDto item, {
  required AppLocalizations l10n,
}) {
  final info = item.technicalInfo;
  final parts = <String>[
    ?formatVideoCodecName(info?.codecName),
    ?formatVideoBitRate(info?.videoBitRate, info?.containerBitRate),
    ?formatVideoFrameRate(info?.frameRate),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
