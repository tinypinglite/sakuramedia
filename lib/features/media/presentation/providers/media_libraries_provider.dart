import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';

part 'media_libraries_provider.g.dart';

/// 媒体库列表 + 派生的存储描述表。存储描述在 State 构造时一次计算好，
/// 避免 UI 每次 rebuild 重复走 `buildMediaStorageDescriptors`。
@immutable
class MediaLibrariesState {
  MediaLibrariesState({
    List<MediaLibraryDto> libraries = const <MediaLibraryDto>[],
  }) : libraries = List<MediaLibraryDto>.unmodifiable(libraries),
       storageDescriptors = Map<int, MediaStorageDescriptor>.unmodifiable(
         buildMediaStorageDescriptors(libraries),
       ),
       cloud115Libraries = List<MediaLibraryDto>.unmodifiable(
         libraries.where((library) => library.isCloud115),
       );

  static const MediaLibrariesState empty = MediaLibrariesState._empty();

  const MediaLibrariesState._empty()
    : libraries = const <MediaLibraryDto>[],
      storageDescriptors = const <int, MediaStorageDescriptor>{},
      cloud115Libraries = const <MediaLibraryDto>[];

  final List<MediaLibraryDto> libraries;
  final Map<int, MediaStorageDescriptor> storageDescriptors;

  /// 供秒传目标弹窗按需消费——只列出 115 类型的媒体库。
  final List<MediaLibraryDto> cloud115Libraries;

  bool get isEmpty => libraries.isEmpty;
  bool get isNotEmpty => libraries.isNotEmpty;
}

Duration? noMediaLibrariesRetry(int retryCount, Object error) => null;

/// 媒体库列表 provider：keepAlive；两页（媒体管理 + 媒体维护）与秒传弹窗共享一份，
/// 避免每次进 tab 各拉一次。加载失败以 `AsyncError` 呈现，消费方可 fallback
/// 到 [MediaLibrariesState.empty]（对齐 legacy 行为——库加载失败不阻断主流程）。
@Riverpod(keepAlive: true, retry: noMediaLibrariesRetry)
class MediaLibraries extends _$MediaLibraries {
  bool _disposed = false;

  @override
  Future<MediaLibrariesState> build() async {
    ref.onDispose(() => _disposed = true);
    final libraries = await ref
        .read(mediaLibrariesApiProvider)
        .getLibraries();
    return MediaLibrariesState(libraries: libraries);
  }

  /// 保留态刷新：不切 [AsyncLoading]；失败返回中文错误消息由页面 toast。
  Future<String?> refresh() async {
    try {
      final libraries = await ref
          .read(mediaLibrariesApiProvider)
          .getLibraries();
      if (_disposed) return null;
      state = AsyncData(MediaLibrariesState(libraries: libraries));
      return null;
    } catch (error) {
      return apiErrorMessage(error, fallback: '媒体库加载失败');
    }
  }

  /// 强制重新加载：切 [AsyncLoading] → 拉列表 → 覆盖。
  Future<void> reload() async {
    state = AsyncLoading<MediaLibrariesState>();
    final next = await AsyncValue.guard<MediaLibrariesState>(() async {
      final libraries = await ref
          .read(mediaLibrariesApiProvider)
          .getLibraries();
      return MediaLibrariesState(libraries: libraries);
    });
    if (!_disposed) {
      state = next;
    }
  }
}
