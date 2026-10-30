// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_tags_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MediaTags)
final mediaTagsProvider = MediaTagsProvider._();

final class MediaTagsProvider
    extends $AsyncNotifierProvider<MediaTags, List<MediaTagDto>> {
  MediaTagsProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'mediaTagsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaTagsHash();

  @$internal
  @override
  MediaTags create() => MediaTags();
}

String _$mediaTagsHash() => r'97f244428aa33ca389caba75bcd560633e35a908';

abstract class _$MediaTags extends $AsyncNotifier<List<MediaTagDto>> {
  FutureOr<List<MediaTagDto>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<MediaTagDto>>, List<MediaTagDto>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<MediaTagDto>>, List<MediaTagDto>>,
              AsyncValue<List<MediaTagDto>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
