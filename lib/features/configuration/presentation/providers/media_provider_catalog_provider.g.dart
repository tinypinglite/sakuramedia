// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_provider_catalog_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 当前账号可用的媒体 Provider Bundle 目录。

@ProviderFor(MediaProviderCatalog)
final mediaProviderCatalogProvider = MediaProviderCatalogProvider._();

/// 当前账号可用的媒体 Provider Bundle 目录。
final class MediaProviderCatalogProvider
    extends
        $AsyncNotifierProvider<MediaProviderCatalog, List<MediaProviderDto>> {
  /// 当前账号可用的媒体 Provider Bundle 目录。
  MediaProviderCatalogProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'mediaProviderCatalogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaProviderCatalogHash();

  @$internal
  @override
  MediaProviderCatalog create() => MediaProviderCatalog();
}

String _$mediaProviderCatalogHash() =>
    r'6572be1dddb3bbfcc62ddfaa44624532f98799e0';

/// 当前账号可用的媒体 Provider Bundle 目录。

abstract class _$MediaProviderCatalog
    extends $AsyncNotifier<List<MediaProviderDto>> {
  FutureOr<List<MediaProviderDto>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<MediaProviderDto>>, List<MediaProviderDto>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<MediaProviderDto>>,
                List<MediaProviderDto>
              >,
              AsyncValue<List<MediaProviderDto>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
