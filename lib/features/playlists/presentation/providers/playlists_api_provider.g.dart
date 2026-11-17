// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlists_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// playlists 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(playlistsApi)
final playlistsApiProvider = PlaylistsApiProvider._();

/// playlists 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class PlaylistsApiProvider
    extends $FunctionalProvider<PlaylistsApi, PlaylistsApi, PlaylistsApi>
    with $Provider<PlaylistsApi> {
  /// playlists 域 API 的 Riverpod 入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  PlaylistsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playlistsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playlistsApiHash();

  @$internal
  @override
  $ProviderElement<PlaylistsApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PlaylistsApi create(Ref ref) {
    return playlistsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaylistsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaylistsApi>(value),
    );
  }
}

String _$playlistsApiHash() => r'187c4ca7849a7e9314d6d7fb62b8c71ad1ed76fe';
