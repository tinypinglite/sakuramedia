// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_order_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 播放列表顺序的持久化桥（SharedPreferences 实现）。
///
/// 测试用 `overrideWithValue(InMemoryPlaylistOrderStore())` 替换。

@ProviderFor(playlistOrderStore)
final playlistOrderStoreProvider = PlaylistOrderStoreProvider._();

/// 播放列表顺序的持久化桥（SharedPreferences 实现）。
///
/// 测试用 `overrideWithValue(InMemoryPlaylistOrderStore())` 替换。

final class PlaylistOrderStoreProvider
    extends
        $FunctionalProvider<
          PlaylistOrderStore,
          PlaylistOrderStore,
          PlaylistOrderStore
        >
    with $Provider<PlaylistOrderStore> {
  /// 播放列表顺序的持久化桥（SharedPreferences 实现）。
  ///
  /// 测试用 `overrideWithValue(InMemoryPlaylistOrderStore())` 替换。
  PlaylistOrderStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playlistOrderStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playlistOrderStoreHash();

  @$internal
  @override
  $ProviderElement<PlaylistOrderStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlaylistOrderStore create(Ref ref) {
    return playlistOrderStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaylistOrderStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaylistOrderStore>(value),
    );
  }
}

String _$playlistOrderStoreHash() =>
    r'd7b5789933055ce1af345d21e322e13e3c3190b7';
