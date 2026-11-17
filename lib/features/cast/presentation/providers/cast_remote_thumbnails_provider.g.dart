// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cast_remote_thumbnails_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 遥控页的缩略图列表（与播放器同源数据）。

@ProviderFor(castRemoteThumbnails)
final castRemoteThumbnailsProvider = CastRemoteThumbnailsFamily._();

/// 遥控页的缩略图列表（与播放器同源数据）。

final class CastRemoteThumbnailsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MovieMediaThumbnailDto>>,
          List<MovieMediaThumbnailDto>,
          FutureOr<List<MovieMediaThumbnailDto>>
        >
    with
        $FutureModifier<List<MovieMediaThumbnailDto>>,
        $FutureProvider<List<MovieMediaThumbnailDto>> {
  /// 遥控页的缩略图列表（与播放器同源数据）。
  CastRemoteThumbnailsProvider._({
    required CastRemoteThumbnailsFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'castRemoteThumbnailsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$castRemoteThumbnailsHash();

  @override
  String toString() {
    return r'castRemoteThumbnailsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<MovieMediaThumbnailDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MovieMediaThumbnailDto>> create(Ref ref) {
    final argument = this.argument as int;
    return castRemoteThumbnails(ref, mediaId: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CastRemoteThumbnailsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$castRemoteThumbnailsHash() =>
    r'8bc5a10618909dffee54be2e9bcb4ce363d9509e';

/// 遥控页的缩略图列表（与播放器同源数据）。

final class CastRemoteThumbnailsFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<List<MovieMediaThumbnailDto>>, int> {
  CastRemoteThumbnailsFamily._()
    : super(
        retry: null,
        name: r'castRemoteThumbnailsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 遥控页的缩略图列表（与播放器同源数据）。

  CastRemoteThumbnailsProvider call({required int mediaId}) =>
      CastRemoteThumbnailsProvider._(argument: mediaId, from: this);

  @override
  String toString() => r'castRemoteThumbnailsProvider';
}
