import 'package:sakuramedia/features/media/data/duplicate_media_group_dto.dart';
import 'package:sakuramedia/features/media/data/invalid_media_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_point_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/multi_version_movie_dto.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 媒体相关加载态占位数据：真实 DTO + [BoneMock] 文案，
/// 供 `AppSkeletonizer` 渲染与真实卡片 / 选项行同形的静态骨架。
List<MediaListItemDto> mediaListItemPlaceholders({
  int count = 6,
  int idOffset = 0,
}) {
  return List<MediaListItemDto>.generate(
    count,
    (index) => MediaListItemDto(
      id: -1 - idOffset - index,
      kind: MediaListItemKind.jav,
      movieNumber: 'ABC-${(idOffset + index + 1).toString().padLeft(3, '0')}',
      title: BoneMock.words(3),
      coverImage: null,
      libraryId: null,
      libraryName: null,
      fileName: BoneMock.words(2),
      fileSizeBytes: 1024 * 1024 * 1024,
      durationSeconds: 3600,
      resolution: '1080p',
      valid: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      thumbnailGenerationState: MediaThumbnailGenerationState.succeeded,
    ),
    growable: false,
  );
}

List<InvalidMediaDto> invalidMediaPlaceholders({int count = 6}) {
  return List<InvalidMediaDto>.generate(
    count,
    (index) => InvalidMediaDto(
      id: -1 - index,
      movieNumber: 'ABC-${(index + 1).toString().padLeft(3, '0')}',
      movieTitle: BoneMock.words(3),
      coverImage: null,
      thinCoverImage: null,
      fileName: BoneMock.words(2),
      libraryId: null,
      libraryName: null,
      fileSizeBytes: 1024 * 1024 * 1024,
      updatedAt: DateTime(2026, 1, 1),
    ),
    growable: false,
  );
}

List<DuplicateMediaGroupDto> duplicateMediaGroupPlaceholders({int count = 2}) {
  return List<DuplicateMediaGroupDto>.generate(
    count,
    (index) => DuplicateMediaGroupDto(
      kind: MediaListItemKind.jav,
      mediaCount: 2,
      mediaItems: mediaListItemPlaceholders(count: 2, idOffset: index * 2),
    ),
    growable: false,
  );
}

List<MultiVersionMovieDto> multiVersionMoviePlaceholders({int count = 2}) {
  return List<MultiVersionMovieDto>.generate(
    count,
    (index) => MultiVersionMovieDto(
      movieNumber: 'ABC-${(index + 1).toString().padLeft(3, '0')}',
      mediaCount: 2,
      mediaItems: mediaListItemPlaceholders(count: 2, idOffset: index * 2),
    ),
    growable: false,
  );
}

List<MediaPointListItemDto> mediaPointListItemPlaceholders({int count = 6}) {
  return List<MediaPointListItemDto>.generate(
    count,
    (index) => MediaPointListItemDto(
      pointId: -1 - index,
      mediaId: -1 - index,
      movieNumber: 'ABC-${(index + 1).toString().padLeft(3, '0')}',
      thumbnailId: -1 - index,
      offsetSeconds: 90,
      image: null,
      createdAt: null,
    ),
    growable: false,
  );
}
