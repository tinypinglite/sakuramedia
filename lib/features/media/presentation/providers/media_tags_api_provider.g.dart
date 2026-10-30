// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_tags_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(mediaTagsApi)
final mediaTagsApiProvider = MediaTagsApiProvider._();

final class MediaTagsApiProvider
    extends $FunctionalProvider<MediaTagsApi, MediaTagsApi, MediaTagsApi>
    with $Provider<MediaTagsApi> {
  MediaTagsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaTagsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaTagsApiHash();

  @$internal
  @override
  $ProviderElement<MediaTagsApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MediaTagsApi create(Ref ref) {
    return mediaTagsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaTagsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaTagsApi>(value),
    );
  }
}

String _$mediaTagsApiHash() => r'd7c38ba4f0bb3f78f79f49a52262caa71190e647';
