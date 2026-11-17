// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_playlist_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 按 `kind` 查找系统播放列表（收藏 / 最近播放）。
///
/// 后端在首次产生播放记录时才创建「最近播放」，收藏由初始化流程预置，
/// 因此列表不存在时返回 null，由页面展示空态。

@ProviderFor(systemPlaylist)
final systemPlaylistProvider = SystemPlaylistFamily._();

/// 按 `kind` 查找系统播放列表（收藏 / 最近播放）。
///
/// 后端在首次产生播放记录时才创建「最近播放」，收藏由初始化流程预置，
/// 因此列表不存在时返回 null，由页面展示空态。

final class SystemPlaylistProvider
    extends
        $FunctionalProvider<
          AsyncValue<PlaylistDto?>,
          PlaylistDto?,
          FutureOr<PlaylistDto?>
        >
    with $FutureModifier<PlaylistDto?>, $FutureProvider<PlaylistDto?> {
  /// 按 `kind` 查找系统播放列表（收藏 / 最近播放）。
  ///
  /// 后端在首次产生播放记录时才创建「最近播放」，收藏由初始化流程预置，
  /// 因此列表不存在时返回 null，由页面展示空态。
  SystemPlaylistProvider._({
    required SystemPlaylistFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'systemPlaylistProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$systemPlaylistHash();

  @override
  String toString() {
    return r'systemPlaylistProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<PlaylistDto?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PlaylistDto?> create(Ref ref) {
    final argument = this.argument as String;
    return systemPlaylist(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SystemPlaylistProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$systemPlaylistHash() => r'b1aec7f4065533f7fc52d3b26732ca223e7c78ae';

/// 按 `kind` 查找系统播放列表（收藏 / 最近播放）。
///
/// 后端在首次产生播放记录时才创建「最近播放」，收藏由初始化流程预置，
/// 因此列表不存在时返回 null，由页面展示空态。

final class SystemPlaylistFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<PlaylistDto?>, String> {
  SystemPlaylistFamily._()
    : super(
        retry: null,
        name: r'systemPlaylistProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 按 `kind` 查找系统播放列表（收藏 / 最近播放）。
  ///
  /// 后端在首次产生播放记录时才创建「最近播放」，收藏由初始化流程预置，
  /// 因此列表不存在时返回 null，由页面展示空态。

  SystemPlaylistProvider call(String kind) =>
      SystemPlaylistProvider._(argument: kind, from: this);

  @override
  String toString() => r'systemPlaylistProvider';
}
