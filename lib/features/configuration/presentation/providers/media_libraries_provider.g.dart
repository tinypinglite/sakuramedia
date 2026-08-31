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

String _$mediaLibrariesHash() => r'c274deb39f3bab18919fa8b6d8f8da604b2300bf';

/// 跨桌面 configuration tab 与移动设置页共享的媒体库列表。

abstract class _$MediaLibraries extends $AsyncNotifier<List<MediaLibraryDto>> {
  FutureOr<List<MediaLibraryDto>> build();
  @$mustCallSuper
  @override
  void runBuild() {
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
    element.handleCreate(ref, build);
  }
}
