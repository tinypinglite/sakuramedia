// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 播放列表元信息（详情页头部横幅、总数展示）。
///
/// autoDispose family(playlistId)：每个 detail 页独立实例，离开即释放。
///
/// 迁移前对应：`PlaylistDetailController`。特化错误路径：`404` /
/// `playlist_not_found` 返回「未找到该播放列表」，其余走通用文案。

@ProviderFor(PlaylistDetail)
final playlistDetailProvider = PlaylistDetailFamily._();

/// 播放列表元信息（详情页头部横幅、总数展示）。
///
/// autoDispose family(playlistId)：每个 detail 页独立实例，离开即释放。
///
/// 迁移前对应：`PlaylistDetailController`。特化错误路径：`404` /
/// `playlist_not_found` 返回「未找到该播放列表」，其余走通用文案。
final class PlaylistDetailProvider
    extends $AsyncNotifierProvider<PlaylistDetail, PlaylistDto> {
  /// 播放列表元信息（详情页头部横幅、总数展示）。
  ///
  /// autoDispose family(playlistId)：每个 detail 页独立实例，离开即释放。
  ///
  /// 迁移前对应：`PlaylistDetailController`。特化错误路径：`404` /
  /// `playlist_not_found` 返回「未找到该播放列表」，其余走通用文案。
  PlaylistDetailProvider._({
    required PlaylistDetailFamily super.from,
    required int super.argument,
  }) : super(
         retry: kNoAsyncNotifierRetry,
         name: r'playlistDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$playlistDetailHash();

  @override
  String toString() {
    return r'playlistDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PlaylistDetail create() => PlaylistDetail();

  @override
  bool operator ==(Object other) {
    return other is PlaylistDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$playlistDetailHash() => r'098b933b043ffb2e6fdd3063d7c66626bfbaaf5b';

/// 播放列表元信息（详情页头部横幅、总数展示）。
///
/// autoDispose family(playlistId)：每个 detail 页独立实例，离开即释放。
///
/// 迁移前对应：`PlaylistDetailController`。特化错误路径：`404` /
/// `playlist_not_found` 返回「未找到该播放列表」，其余走通用文案。

final class PlaylistDetailFamily extends $Family
    with
        $ClassFamilyOverride<
          PlaylistDetail,
          AsyncValue<PlaylistDto>,
          PlaylistDto,
          FutureOr<PlaylistDto>,
          int
        > {
  PlaylistDetailFamily._()
    : super(
        retry: kNoAsyncNotifierRetry,
        name: r'playlistDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 播放列表元信息（详情页头部横幅、总数展示）。
  ///
  /// autoDispose family(playlistId)：每个 detail 页独立实例，离开即释放。
  ///
  /// 迁移前对应：`PlaylistDetailController`。特化错误路径：`404` /
  /// `playlist_not_found` 返回「未找到该播放列表」，其余走通用文案。

  PlaylistDetailProvider call(int playlistId) =>
      PlaylistDetailProvider._(argument: playlistId, from: this);

  @override
  String toString() => r'playlistDetailProvider';
}

/// 播放列表元信息（详情页头部横幅、总数展示）。
///
/// autoDispose family(playlistId)：每个 detail 页独立实例，离开即释放。
///
/// 迁移前对应：`PlaylistDetailController`。特化错误路径：`404` /
/// `playlist_not_found` 返回「未找到该播放列表」，其余走通用文案。

abstract class _$PlaylistDetail extends $AsyncNotifier<PlaylistDto> {
  late final _$args = ref.$arg as int;
  int get playlistId => _$args;

  FutureOr<PlaylistDto> build(int playlistId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PlaylistDto>, PlaylistDto>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PlaylistDto>, PlaylistDto>,
              AsyncValue<PlaylistDto>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
