import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/media_libraries_provider.dart'
    as configuration;
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'media_libraries_provider.g.dart';

/// 媒体库列表 + 按 id 索引。媒体内容只依赖 provider-neutral 的媒体库 DTO，
/// 不在 media 域重新引入存储后端分支。
@immutable
class MediaLibrariesState {
  MediaLibrariesState({
    List<MediaLibraryDto> libraries = const <MediaLibraryDto>[],
  }) : libraries = List<MediaLibraryDto>.unmodifiable(libraries),
       librariesById = Map<int, MediaLibraryDto>.unmodifiable(
         <int, MediaLibraryDto>{
           for (final library in libraries) library.id: library,
         },
       );

  static const MediaLibrariesState empty = MediaLibrariesState._empty();

  const MediaLibrariesState._empty()
    : libraries = const <MediaLibraryDto>[],
      librariesById = const <int, MediaLibraryDto>{};

  final List<MediaLibraryDto> libraries;
  final Map<int, MediaLibraryDto> librariesById;

  bool get isEmpty => libraries.isEmpty;
  bool get isNotEmpty => libraries.isNotEmpty;
}

/// 配置域媒体库 provider 的派生投影：keepAlive；媒体管理页与维护页共享一份，
/// 避免每次进 tab 各拉一次。列表更新由配置域 owner 推送，
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
