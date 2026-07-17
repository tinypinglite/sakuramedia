// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_libraries_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 媒体库列表 provider：keepAlive；两页（媒体管理 + 媒体维护）与秒传弹窗共享一份，
/// 避免每次进 tab 各拉一次。加载失败以 `AsyncError` 呈现，消费方可 fallback
/// 到 [MediaLibrariesState.empty]（对齐 legacy 行为——库加载失败不阻断主流程）。

@ProviderFor(MediaLibraries)
final mediaLibrariesProvider = MediaLibrariesProvider._();

/// 媒体库列表 provider：keepAlive；两页（媒体管理 + 媒体维护）与秒传弹窗共享一份，
/// 避免每次进 tab 各拉一次。加载失败以 `AsyncError` 呈现，消费方可 fallback
/// 到 [MediaLibrariesState.empty]（对齐 legacy 行为——库加载失败不阻断主流程）。
final class MediaLibrariesProvider
    extends $AsyncNotifierProvider<MediaLibraries, MediaLibrariesState> {
  /// 媒体库列表 provider：keepAlive；两页（媒体管理 + 媒体维护）与秒传弹窗共享一份，
  /// 避免每次进 tab 各拉一次。加载失败以 `AsyncError` 呈现，消费方可 fallback
  /// 到 [MediaLibrariesState.empty]（对齐 legacy 行为——库加载失败不阻断主流程）。
  MediaLibrariesProvider._()
    : super(
        from: null,
        argument: null,
        retry: noMediaLibrariesRetry,
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

String _$mediaLibrariesHash() => r'24351b559bbaa6d7bde4533e8805ea80bcde33c9';

/// 媒体库列表 provider：keepAlive；两页（媒体管理 + 媒体维护）与秒传弹窗共享一份，
/// 避免每次进 tab 各拉一次。加载失败以 `AsyncError` 呈现，消费方可 fallback
/// 到 [MediaLibrariesState.empty]（对齐 legacy 行为——库加载失败不阻断主流程）。

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
