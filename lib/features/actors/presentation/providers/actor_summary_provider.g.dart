// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'actor_summary_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 缓存页（桌面 / 移动演员列表）共用的 autoDispose family。
///
/// provider 默认随无监听者释放；页面在 `initState` 通过
/// [cacheLink] 交给 `RiverpodPageCache`，从而精确复刻旧的「LRU 24 + 登出
/// 清空」寿命，而不是把列表无限常驻在 ProviderScope 里。

@ProviderFor(ActorSummary)
final actorSummaryProvider = ActorSummaryFamily._();

/// 缓存页（桌面 / 移动演员列表）共用的 autoDispose family。
///
/// provider 默认随无监听者释放；页面在 `initState` 通过
/// [cacheLink] 交给 `RiverpodPageCache`，从而精确复刻旧的「LRU 24 + 登出
/// 清空」寿命，而不是把列表无限常驻在 ProviderScope 里。
final class ActorSummaryProvider
    extends $AsyncNotifierProvider<ActorSummary, ActorSummaryState> {
  /// 缓存页（桌面 / 移动演员列表）共用的 autoDispose family。
  ///
  /// provider 默认随无监听者释放；页面在 `initState` 通过
  /// [cacheLink] 交给 `RiverpodPageCache`，从而精确复刻旧的「LRU 24 + 登出
  /// 清空」寿命，而不是把列表无限常驻在 ProviderScope 里。
  ActorSummaryProvider._({
    required ActorSummaryFamily super.from,
    required ActorSummaryScope super.argument,
  }) : super(
         retry: kNoAsyncNotifierRetry,
         name: r'actorSummaryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$actorSummaryHash();

  @override
  String toString() {
    return r'actorSummaryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ActorSummary create() => ActorSummary();

  @override
  bool operator ==(Object other) {
    return other is ActorSummaryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$actorSummaryHash() => r'b24f9f9e60bc39bc4b1d482dbfbfc07b74f51009';

/// 缓存页（桌面 / 移动演员列表）共用的 autoDispose family。
///
/// provider 默认随无监听者释放；页面在 `initState` 通过
/// [cacheLink] 交给 `RiverpodPageCache`，从而精确复刻旧的「LRU 24 + 登出
/// 清空」寿命，而不是把列表无限常驻在 ProviderScope 里。

final class ActorSummaryFamily extends $Family
    with
        $ClassFamilyOverride<
          ActorSummary,
          AsyncValue<ActorSummaryState>,
          ActorSummaryState,
          FutureOr<ActorSummaryState>,
          ActorSummaryScope
        > {
  ActorSummaryFamily._()
    : super(
        retry: kNoAsyncNotifierRetry,
        name: r'actorSummaryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 缓存页（桌面 / 移动演员列表）共用的 autoDispose family。
  ///
  /// provider 默认随无监听者释放；页面在 `initState` 通过
  /// [cacheLink] 交给 `RiverpodPageCache`，从而精确复刻旧的「LRU 24 + 登出
  /// 清空」寿命，而不是把列表无限常驻在 ProviderScope 里。

  ActorSummaryProvider call(ActorSummaryScope scope) =>
      ActorSummaryProvider._(argument: scope, from: this);

  @override
  String toString() => r'actorSummaryProvider';
}

/// 缓存页（桌面 / 移动演员列表）共用的 autoDispose family。
///
/// provider 默认随无监听者释放；页面在 `initState` 通过
/// [cacheLink] 交给 `RiverpodPageCache`，从而精确复刻旧的「LRU 24 + 登出
/// 清空」寿命，而不是把列表无限常驻在 ProviderScope 里。

abstract class _$ActorSummary extends $AsyncNotifier<ActorSummaryState> {
  late final _$args = ref.$arg as ActorSummaryScope;
  ActorSummaryScope get scope => _$args;

  FutureOr<ActorSummaryState> build(ActorSummaryScope scope);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ActorSummaryState>, ActorSummaryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ActorSummaryState>, ActorSummaryState>,
              AsyncValue<ActorSummaryState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
