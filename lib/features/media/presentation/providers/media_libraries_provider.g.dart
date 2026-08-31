// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_libraries_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 配置域媒体库 provider 的派生投影：keepAlive；媒体管理页与维护页共享一份，
/// 避免每次进 tab 各拉一次。列表更新由配置域 owner 推送，
/// 本 provider 只负责构造 [MediaLibrariesState] 的派生字段。

@ProviderFor(MediaLibraries)
final mediaLibrariesProvider = MediaLibrariesProvider._();

/// 配置域媒体库 provider 的派生投影：keepAlive；媒体管理页与维护页共享一份，
/// 避免每次进 tab 各拉一次。列表更新由配置域 owner 推送，
/// 本 provider 只负责构造 [MediaLibrariesState] 的派生字段。
final class MediaLibrariesProvider
    extends $AsyncNotifierProvider<MediaLibraries, MediaLibrariesState> {
  /// 配置域媒体库 provider 的派生投影：keepAlive；媒体管理页与维护页共享一份，
  /// 避免每次进 tab 各拉一次。列表更新由配置域 owner 推送，
  /// 本 provider 只负责构造 [MediaLibrariesState] 的派生字段。
  MediaLibrariesProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'mediaLibrariesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaLibrariesHash();

  @$internal
  @override
  MediaLibraries create() => MediaLibraries();
}

String _$mediaLibrariesHash() => r'366002323d44aeef1103bfb341c14d05fd819711';

/// 配置域媒体库 provider 的派生投影：keepAlive；媒体管理页与维护页共享一份，
/// 避免每次进 tab 各拉一次。列表更新由配置域 owner 推送，
/// 本 provider 只负责构造 [MediaLibrariesState] 的派生字段。

abstract class _$MediaLibraries extends $AsyncNotifier<MediaLibrariesState> {
  FutureOr<MediaLibrariesState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<MediaLibrariesState>, MediaLibrariesState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MediaLibrariesState>, MediaLibrariesState>,
              AsyncValue<MediaLibrariesState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
