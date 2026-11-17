// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_views_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 最近浏览列表（最新在前，一次拉后端保留上限）。
///
/// - 单实例：概览区块只展示前若干条、更多页列全，共享同一份数据；
///   打开更多页不额外请求，刷新只发一次。
/// - 订阅变更广播到达时就地补丁订阅心状态，不整页重拉（浏览历史不因订阅状态变化而增删）。

@ProviderFor(RecentViews)
final recentViewsProvider = RecentViewsProvider._();

/// 最近浏览列表（最新在前，一次拉后端保留上限）。
///
/// - 单实例：概览区块只展示前若干条、更多页列全，共享同一份数据；
///   打开更多页不额外请求，刷新只发一次。
/// - 订阅变更广播到达时就地补丁订阅心状态，不整页重拉（浏览历史不因订阅状态变化而增删）。
final class RecentViewsProvider
    extends $AsyncNotifierProvider<RecentViews, List<RecentViewEntryDto>> {
  /// 最近浏览列表（最新在前，一次拉后端保留上限）。
  ///
  /// - 单实例：概览区块只展示前若干条、更多页列全，共享同一份数据；
  ///   打开更多页不额外请求，刷新只发一次。
  /// - 订阅变更广播到达时就地补丁订阅心状态，不整页重拉（浏览历史不因订阅状态变化而增删）。
  RecentViewsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentViewsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentViewsHash();

  @$internal
  @override
  RecentViews create() => RecentViews();
}

String _$recentViewsHash() => r'fd712e1fdd888af2c7e0aa2678c3abf8dd8c4118';

/// 最近浏览列表（最新在前，一次拉后端保留上限）。
///
/// - 单实例：概览区块只展示前若干条、更多页列全，共享同一份数据；
///   打开更多页不额外请求，刷新只发一次。
/// - 订阅变更广播到达时就地补丁订阅心状态，不整页重拉（浏览历史不因订阅状态变化而增删）。

abstract class _$RecentViews extends $AsyncNotifier<List<RecentViewEntryDto>> {
  FutureOr<List<RecentViewEntryDto>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<RecentViewEntryDto>>,
              List<RecentViewEntryDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<RecentViewEntryDto>>,
                List<RecentViewEntryDto>
              >,
              AsyncValue<List<RecentViewEntryDto>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
