// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_provider_catalog_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mediaProviderCatalogApi)
final mediaProviderCatalogApiProvider = MediaProviderCatalogApiProvider._();

final class MediaProviderCatalogApiProvider
    extends
        $FunctionalProvider<
          MediaProviderCatalogApi,
          MediaProviderCatalogApi,
          MediaProviderCatalogApi
        >
    with $Provider<MediaProviderCatalogApi> {
  MediaProviderCatalogApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaProviderCatalogApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaProviderCatalogApiHash();

  @$internal
  @override
  $ProviderElement<MediaProviderCatalogApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MediaProviderCatalogApi create(Ref ref) {
    return mediaProviderCatalogApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaProviderCatalogApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaProviderCatalogApi>(value),
    );
  }
}

String _$mediaProviderCatalogApiHash() =>
    r'e229cbf2076655e2671f1e7588cce054d527d3f3';
