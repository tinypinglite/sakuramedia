import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

class InvalidMediaDto {
  const InvalidMediaDto({
    required this.id,
    this.movieNumber,
    this.videoItemId,
    required this.movieTitle,
    required this.coverImage,
    required this.thinCoverImage,
    required this.fileName,
    required this.libraryId,
    required this.libraryName,
    required this.fileSizeBytes,
    required this.updatedAt,
    this.invalidReason,
    this.invalidDetail = const <String, dynamic>{},
  });

  final int id;
  final String? movieNumber;
  final int? videoItemId;
  final String? movieTitle;
  final MovieImageDto? coverImage;
  final MovieImageDto? thinCoverImage;
  final String fileName;
  final int? libraryId;
  final String? libraryName;
  final int fileSizeBytes;
  final DateTime? updatedAt;
  final String? invalidReason;
  final Map<String, dynamic> invalidDetail;

  String displayInvalidReason(AppLocalizations l10n) {
    switch (invalidReason) {
      case 'file_missing':
        return l10n.mediaListInvalidReasonFileMissing;
      case 'container_invalid':
        return l10n.mediaListInvalidReasonContainerInvalid;
      case 'moov_missing':
        return l10n.mediaListInvalidReasonMoovMissing;
      case 'video_stream_missing':
        return l10n.mediaListInvalidReasonVideoStreamMissing;
      case 'interleave_bad':
        final gap = invalidDetail['max_gap_mib'];
        if (gap is num) {
          final value = gap >= 100
              ? gap.toStringAsFixed(0)
              : gap.toStringAsFixed(1);
          return l10n.mediaListInvalidReasonInterleaveBadWithGap(value);
        }
        return l10n.mediaListInvalidReasonInterleaveBad;
      default:
        return l10n.mediaListInvalidReasonUnknown;
    }
  }

  /// 展示用标题；未命名时回退语言包里的「未命名媒体」。
  String displayTitle(AppLocalizations l10n) {
    final title = movieTitle?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }
    return l10n.mediaListUnnamedMedia;
  }

  String? get preferredCoverUrl {
    final thinUrl = thinCoverImage?.origin.trim();
    if (thinUrl != null && thinUrl.isNotEmpty) {
      return thinUrl;
    }
    final coverUrl = coverImage?.origin.trim();
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return coverUrl;
    }
    return null;
  }

  bool get usesThinCover {
    final thinUrl = thinCoverImage?.origin.trim();
    return thinUrl != null && thinUrl.isNotEmpty;
  }

  factory InvalidMediaDto.fromJson(Map<String, dynamic> json) {
    return InvalidMediaDto(
      id: asInt(json['id']),
      movieNumber: asStringOrNull(json['movie_number'], trim: true),
      videoItemId: asIntOrNull(json['video_item_id']),
      movieTitle: asStringOrNull(json['movie_title'], trim: true),
      coverImage: _movieImageFromJson(json['cover_image']),
      thinCoverImage: _movieImageFromJson(json['thin_cover_image']),
      fileName: json['file_name'] as String? ?? '',
      libraryId: asIntOrNull(json['library_id']),
      libraryName: asStringOrNull(json['library_name'], trim: true),
      fileSizeBytes: asInt(json['file_size_bytes']),
      updatedAt: asDateTime(json['updated_at']),
      invalidReason: asStringOrNull(json['invalid_reason'], trim: true),
      invalidDetail: asMap(json['invalid_detail']),
    );
  }

  static MovieImageDto? _movieImageFromJson(dynamic value) {
    if (value is Map<String, dynamic>) {
      return MovieImageDto.fromJson(value);
    }
    if (value is Map) {
      return MovieImageDto.fromJson(
        value.map(
          (dynamic key, dynamic data) => MapEntry(key.toString(), data),
        ),
      );
    }
    return null;
  }
}
