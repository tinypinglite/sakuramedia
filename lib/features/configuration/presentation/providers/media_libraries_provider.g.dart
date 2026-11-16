// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_libraries_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 跨桌面 configuration tab 与移动设置页共享的媒体库列表。

@ProviderFor(MediaLibraries)
final mediaLibrariesProvider = MediaLibrariesProvider._();

/// 跨桌面 configuration tab 与移动设置页共享的媒体库列表。
final class MediaLibrariesProvider
    extends $AsyncNotifierProvider<MediaLibraries, List<MediaLibraryDto>> {
  /// 跨桌面 configuration tab 与移动设置页共享的媒体库列表。
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

String _$mediaLibrariesHash() => r'00e4541f1e8769f3a0d64df3fe414c19a46d7c83';

/// 跨桌面 configuration tab 与移动设置页共享的媒体库列表。

abstract class _$MediaLibraries extends $AsyncNotifier<List<MediaLibraryDto>> {
  FutureOr<List<MediaLibraryDto>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<MediaLibraryDto>>, List<MediaLibraryDto>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<MediaLibraryDto>>,
                List<MediaLibraryDto>
              >,
              AsyncValue<List<MediaLibraryDto>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
