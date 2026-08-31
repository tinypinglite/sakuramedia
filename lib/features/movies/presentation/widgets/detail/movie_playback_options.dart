import 'package:sakuramedia/features/media/data/media_play_url_dto.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';

/// 影片详情页「播放源/播放模式」选择的纯函数计算。
///
/// 播放源 = 本地库 / 115 网盘（按媒体所属库的 backend 判定，见
/// [MediaStorageDescriptor.isLocal] / [isCloud115]）；播放模式 = 单个 / 合并。
/// 只统计 `hasPlayableUrl` 的媒体，避免把不可播媒体计进源选项。
class MoviePlaybackSourceOptions {
  const MoviePlaybackSourceOptions({
    required this.localCount,
    required this.cloud115Count,
  });

  final int localCount;
  final int cloud115Count;

  bool get hasBothSources => localCount > 0 && cloud115Count > 0;

  int countOf(MoviePlayUrlSource source) {
    return switch (source) {
      MoviePlayUrlSource.local => localCount,
      MoviePlayUrlSource.cloud115 => cloud115Count,
    };
  }

  /// 默认源：本地优先，其次 115；都不可播返回 `null`。
  MoviePlayUrlSource? get defaultSource {
    if (localCount > 0) {
      return MoviePlayUrlSource.local;
    }
    if (cloud115Count > 0) {
      return MoviePlayUrlSource.cloud115;
    }
    return null;
  }
}

MoviePlaybackSourceOptions resolveMoviePlaybackSourceOptions({
  required List<MovieMediaItemDto> mediaItems,
  required Map<int, MediaStorageDescriptor> storageDescriptors,
}) {
  var localCount = 0;
  var cloud115Count = 0;
  for (final item in mediaItems) {
    if (!item.hasPlayableUrl) {
      continue;
    }
    final storage = resolveMediaStorageDescriptor(
      item.libraryId,
      storageDescriptors,
    );
    if (storage.isCloud115) {
      cloud115Count++;
    } else if (storage.isLocal) {
      localCount++;
    }
  }
  return MoviePlaybackSourceOptions(
    localCount: localCount,
    cloud115Count: cloud115Count,
  );
}

/// 指定源下第一个可播放媒体的 mediaId；该源无媒体时返回 `null`。
int? resolveFirstPlayableMediaId({
  required List<MovieMediaItemDto> mediaItems,
  required Map<int, MediaStorageDescriptor> storageDescriptors,
  required MoviePlayUrlSource source,
}) {
  for (final item in mediaItems) {
    if (!item.hasPlayableUrl) {
      continue;
    }
    final storage = resolveMediaStorageDescriptor(
      item.libraryId,
      storageDescriptors,
    );
    final matches = switch (source) {
      MoviePlayUrlSource.local => storage.isLocal,
      MoviePlayUrlSource.cloud115 => storage.isCloud115,
    };
    if (matches) {
      return item.mediaId;
    }
  }
  return null;
}

/// 按当前播放源过滤 media 列表。source 为 `null` 时不过滤（兜底整片无可播源
/// 的场景，避免列表空掉）；孤儿/未知归属媒体（`libraryId == null` 或库不在
/// [storageDescriptors] 里）严格排除,不在任一源视图出现,避免"选了本地却看到
/// 不明媒体"的歧义。
List<MovieMediaItemDto> filterMediaItemsByPlaybackSource({
  required List<MovieMediaItemDto> mediaItems,
  required Map<int, MediaStorageDescriptor> storageDescriptors,
  required MoviePlayUrlSource? source,
}) {
  if (source == null) {
    return mediaItems;
  }
  return mediaItems.where((item) {
    final storage = resolveMediaStorageDescriptor(
      item.libraryId,
      storageDescriptors,
    );
    return switch (source) {
      MoviePlayUrlSource.local => storage.isLocal,
      MoviePlayUrlSource.cloud115 => storage.isCloud115,
    };
  }).toList(growable: false);
}
