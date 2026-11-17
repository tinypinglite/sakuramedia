// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_targets_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 影片批量「加入播放列表」可选的目标：自定义列表和系统收藏。
///
/// 最近播放由播放行为自动维护，不能作为手动加入目标。

@ProviderFor(playlistTargets)
final playlistTargetsProvider = PlaylistTargetsProvider._();

/// 影片批量「加入播放列表」可选的目标：自定义列表和系统收藏。
///
/// 最近播放由播放行为自动维护，不能作为手动加入目标。

final class PlaylistTargetsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PlaylistDto>>,
          List<PlaylistDto>,
          FutureOr<List<PlaylistDto>>
        >
    with
        $FutureModifier<List<PlaylistDto>>,
        $FutureProvider<List<PlaylistDto>> {
  /// 影片批量「加入播放列表」可选的目标：自定义列表和系统收藏。
  ///
  /// 最近播放由播放行为自动维护，不能作为手动加入目标。
  PlaylistTargetsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playlistTargetsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playlistTargetsHash();

  @$internal
  @override
  $FutureProviderElement<List<PlaylistDto>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PlaylistDto>> create(Ref ref) {
    return playlistTargets(ref);
  }
}

String _$playlistTargetsHash() => r'c9f34dcccd31f1aa4d5801e6863758d3c8c327aa';
