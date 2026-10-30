// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ranking_summary_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 桌面和移动榜单共用的缓存状态。
///
/// 排行榜的筛选元数据与分页数据具有依赖关系，所以把来源、榜单、周期、排序和
/// 订阅 busy 状态放在同一个不可变 state 中；请求顺序与旧 entry 保持一致。

@ProviderFor(RankingSummary)
final rankingSummaryProvider = RankingSummaryFamily._();

/// 桌面和移动榜单共用的缓存状态。
///
/// 排行榜的筛选元数据与分页数据具有依赖关系，所以把来源、榜单、周期、排序和
/// 订阅 busy 状态放在同一个不可变 state 中；请求顺序与旧 entry 保持一致。
final class RankingSummaryProvider
    extends $AsyncNotifierProvider<RankingSummary, RankingSummaryState> {
  /// 桌面和移动榜单共用的缓存状态。
  ///
  /// 排行榜的筛选元数据与分页数据具有依赖关系，所以把来源、榜单、周期、排序和
  /// 订阅 busy 状态放在同一个不可变 state 中；请求顺序与旧 entry 保持一致。
  RankingSummaryProvider._({
    required RankingSummaryFamily super.from,
    required RankingSummaryScope super.argument,
  }) : super(
         retry: kNoAsyncNotifierRetry,
         name: r'rankingSummaryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rankingSummaryHash();

  @override
  String toString() {
    return r'rankingSummaryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RankingSummary create() => RankingSummary();

  @override
  bool operator ==(Object other) {
    return other is RankingSummaryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rankingSummaryHash() => r'd75cffb797376ecac37c5af2c2d72e7bb36809ff';

/// 桌面和移动榜单共用的缓存状态。
///
/// 排行榜的筛选元数据与分页数据具有依赖关系，所以把来源、榜单、周期、排序和
/// 订阅 busy 状态放在同一个不可变 state 中；请求顺序与旧 entry 保持一致。

final class RankingSummaryFamily extends $Family
    with
        $ClassFamilyOverride<
          RankingSummary,
          AsyncValue<RankingSummaryState>,
          RankingSummaryState,
          FutureOr<RankingSummaryState>,
          RankingSummaryScope
        > {
  RankingSummaryFamily._()
    : super(
        retry: kNoAsyncNotifierRetry,
        name: r'rankingSummaryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 桌面和移动榜单共用的缓存状态。
  ///
  /// 排行榜的筛选元数据与分页数据具有依赖关系，所以把来源、榜单、周期、排序和
  /// 订阅 busy 状态放在同一个不可变 state 中；请求顺序与旧 entry 保持一致。

  RankingSummaryProvider call(RankingSummaryScope scope) =>
      RankingSummaryProvider._(argument: scope, from: this);

  @override
  String toString() => r'rankingSummaryProvider';
}

/// 桌面和移动榜单共用的缓存状态。
///
/// 排行榜的筛选元数据与分页数据具有依赖关系，所以把来源、榜单、周期、排序和
/// 订阅 busy 状态放在同一个不可变 state 中；请求顺序与旧 entry 保持一致。

abstract class _$RankingSummary extends $AsyncNotifier<RankingSummaryState> {
  late final _$args = ref.$arg as RankingSummaryScope;
  RankingSummaryScope get scope => _$args;

  FutureOr<RankingSummaryState> build(RankingSummaryScope scope);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<RankingSummaryState>, RankingSummaryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<RankingSummaryState>, RankingSummaryState>,
              AsyncValue<RankingSummaryState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
