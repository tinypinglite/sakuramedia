import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart'
    as configuration;
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

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

/// 配置域媒体库 provider 的派生投影：keepAlive；两页（媒体管理 + 媒体维护）与秒传
/// 弹窗共享一份，避免每次进 tab 各拉一次。列表更新由配置域 owner 推送，
/// 本 provider 只负责构造 [MediaLibrariesState] 的派生字段。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class MediaLibraries extends _$MediaLibraries
    with AsyncNotifierDisposeGuardMixin<MediaLibrariesState> {
  @override
  Future<MediaLibrariesState> build() async {
    invalidateOnSignOut(ref);
    attachDisposeGuard();
    final libraries = await ref.watch(
      configuration.mediaLibrariesProvider.future,
    );
    return MediaLibrariesState(libraries: libraries);
  }

  /// 委托配置域 owner 保留态刷新；失败返回中文错误消息由页面 toast。
  Future<String?> refresh() =>
      ref.read(configuration.mediaLibrariesProvider.notifier).refresh();

  /// 委托配置域 owner 强制重新加载。
  Future<void> reload() =>
      ref.read(configuration.mediaLibrariesProvider.notifier).reload();
}
