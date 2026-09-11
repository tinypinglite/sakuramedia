// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_summary_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 桌面 / 移动 PornBox 共用的缓存分页列表。
///
/// provider 默认 autoDispose；页面在初始化时把 [cacheLink] 交给
/// `RiverpodPageCache`，复刻旧缓存 entry 的 LRU 生命周期。排序、分页与删除
/// 补丁均在这里收敛，View 仅保留滚动、多选和动作弹窗等瞬态状态。

@ProviderFor(VideoSummary)
final videoSummaryProvider = VideoSummaryFamily._();

/// 桌面 / 移动 PornBox 共用的缓存分页列表。
///
/// provider 默认 autoDispose；页面在初始化时把 [cacheLink] 交给
/// `RiverpodPageCache`，复刻旧缓存 entry 的 LRU 生命周期。排序、分页与删除
/// 补丁均在这里收敛，View 仅保留滚动、多选和动作弹窗等瞬态状态。
final class VideoSummaryProvider
    extends $AsyncNotifierProvider<VideoSummary, VideoSummaryState> {
  /// 桌面 / 移动 PornBox 共用的缓存分页列表。
  ///
  /// provider 默认 autoDispose；页面在初始化时把 [cacheLink] 交给
  /// `RiverpodPageCache`，复刻旧缓存 entry 的 LRU 生命周期。排序、分页与删除
  /// 补丁均在这里收敛，View 仅保留滚动、多选和动作弹窗等瞬态状态。
  VideoSummaryProvider._({
    required VideoSummaryFamily super.from,
    required VideoSummaryScope super.argument,
  }) : super(
         retry: kNoAsyncNotifierRetry,
         name: r'videoSummaryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$videoSummaryHash();

  @override
  String toString() {
    return r'videoSummaryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  VideoSummary create() => VideoSummary();

  @override
  bool operator ==(Object other) {
    return other is VideoSummaryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$videoSummaryHash() => r'32a693d6657a4d00235dbe56b35a36561b5b3a87';

/// 桌面 / 移动 PornBox 共用的缓存分页列表。
///
/// provider 默认 autoDispose；页面在初始化时把 [cacheLink] 交给
/// `RiverpodPageCache`，复刻旧缓存 entry 的 LRU 生命周期。排序、分页与删除
/// 补丁均在这里收敛，View 仅保留滚动、多选和动作弹窗等瞬态状态。

final class VideoSummaryFamily extends $Family
    with
        $ClassFamilyOverride<
          VideoSummary,
          AsyncValue<VideoSummaryState>,
          VideoSummaryState,
          FutureOr<VideoSummaryState>,
          VideoSummaryScope
        > {
  VideoSummaryFamily._()
    : super(
        retry: kNoAsyncNotifierRetry,
        name: r'videoSummaryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 桌面 / 移动 PornBox 共用的缓存分页列表。
  ///
  /// provider 默认 autoDispose；页面在初始化时把 [cacheLink] 交给
  /// `RiverpodPageCache`，复刻旧缓存 entry 的 LRU 生命周期。排序、分页与删除
  /// 补丁均在这里收敛，View 仅保留滚动、多选和动作弹窗等瞬态状态。

  VideoSummaryProvider call(VideoSummaryScope scope) =>
      VideoSummaryProvider._(argument: scope, from: this);

  @override
  String toString() => r'videoSummaryProvider';
}

/// 桌面 / 移动 PornBox 共用的缓存分页列表。
///
/// provider 默认 autoDispose；页面在初始化时把 [cacheLink] 交给
/// `RiverpodPageCache`，复刻旧缓存 entry 的 LRU 生命周期。排序、分页与删除
/// 补丁均在这里收敛，View 仅保留滚动、多选和动作弹窗等瞬态状态。

abstract class _$VideoSummary extends $AsyncNotifier<VideoSummaryState> {
  late final _$args = ref.$arg as VideoSummaryScope;
  VideoSummaryScope get scope => _$args;

  FutureOr<VideoSummaryState> build(VideoSummaryScope scope);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<VideoSummaryState>, VideoSummaryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VideoSummaryState>, VideoSummaryState>,
              AsyncValue<VideoSummaryState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
