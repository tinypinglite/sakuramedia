import 'package:sakuramedia/features/videos/data/dto/video_item_detail_dto.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 视频标题兜底：数据层只保留后端原始标题，空标题在展示层回落到语言包。
String videoDisplayTitle(String rawTitle, AppLocalizations l10n) {
  final trimmed = rawTitle.trim();
  return trimmed.isEmpty ? l10n.videoUnnamedTitle : trimmed;
}

extension VideoItemListItemTitleX on VideoItemListItemDto {
  String displayTitle(AppLocalizations l10n) => videoDisplayTitle(title, l10n);
}

extension VideoItemDetailTitleX on VideoItemDetailDto {
  String displayTitle(AppLocalizations l10n) => videoDisplayTitle(title, l10n);
}
