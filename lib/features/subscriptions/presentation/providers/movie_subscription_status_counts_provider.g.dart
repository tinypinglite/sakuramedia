// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_subscription_status_counts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 状态分段签的角标计数。
///
/// **刻意与列表 provider 分开**：计数挂了不该把整页拖成错误态——分段签退化成没有
/// 角标的纯文字签，列表照常可用。反过来列表翻页也不必反复重算计数。
///
/// 任何会改变状态归属的动作（重置查询 / 取消订阅）之后由列表 notifier 调
/// [MovieSubscriptionStatusCounts.refresh] 拉一次，保持角标与列表同步。

@ProviderFor(MovieSubscriptionStatusCounts)
final movieSubscriptionStatusCountsProvider =
    MovieSubscriptionStatusCountsProvider._();

/// 状态分段签的角标计数。
///
/// **刻意与列表 provider 分开**：计数挂了不该把整页拖成错误态——分段签退化成没有
/// 角标的纯文字签，列表照常可用。反过来列表翻页也不必反复重算计数。
///
/// 任何会改变状态归属的动作（重置查询 / 取消订阅）之后由列表 notifier 调
/// [MovieSubscriptionStatusCounts.refresh] 拉一次，保持角标与列表同步。
final class MovieSubscriptionStatusCountsProvider
    extends
        $AsyncNotifierProvider<
          MovieSubscriptionStatusCounts,
          MovieSubscriptionStatusCountsDto
        > {
  /// 状态分段签的角标计数。
  ///
  /// **刻意与列表 provider 分开**：计数挂了不该把整页拖成错误态——分段签退化成没有
  /// 角标的纯文字签，列表照常可用。反过来列表翻页也不必反复重算计数。
  ///
  /// 任何会改变状态归属的动作（重置查询 / 取消订阅）之后由列表 notifier 调
  /// [MovieSubscriptionStatusCounts.refresh] 拉一次，保持角标与列表同步。
  MovieSubscriptionStatusCountsProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'movieSubscriptionStatusCountsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$movieSubscriptionStatusCountsHash();

  @$internal
  @override
  MovieSubscriptionStatusCounts create() => MovieSubscriptionStatusCounts();
}

String _$movieSubscriptionStatusCountsHash() =>
    r'5cc61d7786de3aef640190bea264753fd49ef62a';

/// 状态分段签的角标计数。
///
/// **刻意与列表 provider 分开**：计数挂了不该把整页拖成错误态——分段签退化成没有
/// 角标的纯文字签，列表照常可用。反过来列表翻页也不必反复重算计数。
///
/// 任何会改变状态归属的动作（重置查询 / 取消订阅）之后由列表 notifier 调
/// [MovieSubscriptionStatusCounts.refresh] 拉一次，保持角标与列表同步。

abstract class _$MovieSubscriptionStatusCounts
    extends $AsyncNotifier<MovieSubscriptionStatusCountsDto> {
  FutureOr<MovieSubscriptionStatusCountsDto> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<MovieSubscriptionStatusCountsDto>,
              MovieSubscriptionStatusCountsDto
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<MovieSubscriptionStatusCountsDto>,
                MovieSubscriptionStatusCountsDto
              >,
              AsyncValue<MovieSubscriptionStatusCountsDto>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
