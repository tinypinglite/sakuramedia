// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mutation_events_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 跨页订阅变更广播 —— 单一 provider 兼「事件流 + 发布 API」。
///
/// **消费方**：`ref.listen(movieSubscriptionEventsProvider, (prev, next) {
/// final changes = next.value; if (changes != null) applyChanges(changes); })`
/// 收到后做**就地补丁**（移除 / 改字段），不 invalidate 整页重拉。
///
/// **发起方**：`ref.read(movieSubscriptionEventsProvider.notifier).reportChange(...)`
/// 或 `reportBatch(...)`。单条 / 批量都统一成列表广播一次。
///
/// 迁移前形态：`MovieSubscriptionChangeNotifier extends ChangeNotifier` +
/// broadcaster 桥 provider + Stream 派生 provider 三件套；
/// 现在合成单一 `@Riverpod` class Notifier，`StreamController.broadcast(sync: true)`
/// 承载事件流，`reportXxx` 直接推入。**离屏挂起**：没有监听者时 riverpod 会挂起
/// 派生 Stream，事件缓冲、恢复监听时补投（写测试须挂监听者）。

@ProviderFor(MovieSubscriptionEvents)
final movieSubscriptionEventsProvider = MovieSubscriptionEventsProvider._();

/// 跨页订阅变更广播 —— 单一 provider 兼「事件流 + 发布 API」。
///
/// **消费方**：`ref.listen(movieSubscriptionEventsProvider, (prev, next) {
/// final changes = next.value; if (changes != null) applyChanges(changes); })`
/// 收到后做**就地补丁**（移除 / 改字段），不 invalidate 整页重拉。
///
/// **发起方**：`ref.read(movieSubscriptionEventsProvider.notifier).reportChange(...)`
/// 或 `reportBatch(...)`。单条 / 批量都统一成列表广播一次。
///
/// 迁移前形态：`MovieSubscriptionChangeNotifier extends ChangeNotifier` +
/// broadcaster 桥 provider + Stream 派生 provider 三件套；
/// 现在合成单一 `@Riverpod` class Notifier，`StreamController.broadcast(sync: true)`
/// 承载事件流，`reportXxx` 直接推入。**离屏挂起**：没有监听者时 riverpod 会挂起
/// 派生 Stream，事件缓冲、恢复监听时补投（写测试须挂监听者）。
final class MovieSubscriptionEventsProvider
    extends
        $StreamNotifierProvider<
          MovieSubscriptionEvents,
          List<MovieSubscriptionChange>
        > {
  /// 跨页订阅变更广播 —— 单一 provider 兼「事件流 + 发布 API」。
  ///
  /// **消费方**：`ref.listen(movieSubscriptionEventsProvider, (prev, next) {
  /// final changes = next.value; if (changes != null) applyChanges(changes); })`
  /// 收到后做**就地补丁**（移除 / 改字段），不 invalidate 整页重拉。
  ///
  /// **发起方**：`ref.read(movieSubscriptionEventsProvider.notifier).reportChange(...)`
  /// 或 `reportBatch(...)`。单条 / 批量都统一成列表广播一次。
  ///
  /// 迁移前形态：`MovieSubscriptionChangeNotifier extends ChangeNotifier` +
  /// broadcaster 桥 provider + Stream 派生 provider 三件套；
  /// 现在合成单一 `@Riverpod` class Notifier，`StreamController.broadcast(sync: true)`
  /// 承载事件流，`reportXxx` 直接推入。**离屏挂起**：没有监听者时 riverpod 会挂起
  /// 派生 Stream，事件缓冲、恢复监听时补投（写测试须挂监听者）。
  MovieSubscriptionEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'movieSubscriptionEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$movieSubscriptionEventsHash();

  @$internal
  @override
  MovieSubscriptionEvents create() => MovieSubscriptionEvents();
}

String _$movieSubscriptionEventsHash() =>
    r'7c28fecf3971bc16a42574b65de8aa8e39c4c5be';

/// 跨页订阅变更广播 —— 单一 provider 兼「事件流 + 发布 API」。
///
/// **消费方**：`ref.listen(movieSubscriptionEventsProvider, (prev, next) {
/// final changes = next.value; if (changes != null) applyChanges(changes); })`
/// 收到后做**就地补丁**（移除 / 改字段），不 invalidate 整页重拉。
///
/// **发起方**：`ref.read(movieSubscriptionEventsProvider.notifier).reportChange(...)`
/// 或 `reportBatch(...)`。单条 / 批量都统一成列表广播一次。
///
/// 迁移前形态：`MovieSubscriptionChangeNotifier extends ChangeNotifier` +
/// broadcaster 桥 provider + Stream 派生 provider 三件套；
/// 现在合成单一 `@Riverpod` class Notifier，`StreamController.broadcast(sync: true)`
/// 承载事件流，`reportXxx` 直接推入。**离屏挂起**：没有监听者时 riverpod 会挂起
/// 派生 Stream，事件缓冲、恢复监听时补投（写测试须挂监听者）。

abstract class _$MovieSubscriptionEvents
    extends $StreamNotifier<List<MovieSubscriptionChange>> {
  Stream<List<MovieSubscriptionChange>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<MovieSubscriptionChange>>,
              List<MovieSubscriptionChange>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<MovieSubscriptionChange>>,
                List<MovieSubscriptionChange>
              >,
              AsyncValue<List<MovieSubscriptionChange>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 跨页合集类型（单体/合集）变更广播 —— 与 [MovieSubscriptionEvents] 同范式，
/// 每次广播携带单个 [MovieCollectionTypeChange]。

@ProviderFor(MovieCollectionTypeEvents)
final movieCollectionTypeEventsProvider = MovieCollectionTypeEventsProvider._();

/// 跨页合集类型（单体/合集）变更广播 —— 与 [MovieSubscriptionEvents] 同范式，
/// 每次广播携带单个 [MovieCollectionTypeChange]。
final class MovieCollectionTypeEventsProvider
    extends
        $StreamNotifierProvider<
          MovieCollectionTypeEvents,
          MovieCollectionTypeChange
        > {
  /// 跨页合集类型（单体/合集）变更广播 —— 与 [MovieSubscriptionEvents] 同范式，
  /// 每次广播携带单个 [MovieCollectionTypeChange]。
  MovieCollectionTypeEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'movieCollectionTypeEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$movieCollectionTypeEventsHash();

  @$internal
  @override
  MovieCollectionTypeEvents create() => MovieCollectionTypeEvents();
}

String _$movieCollectionTypeEventsHash() =>
    r'659b05309cc1daf24c23268bbee51883bf4d8a70';

/// 跨页合集类型（单体/合集）变更广播 —— 与 [MovieSubscriptionEvents] 同范式，
/// 每次广播携带单个 [MovieCollectionTypeChange]。

abstract class _$MovieCollectionTypeEvents
    extends $StreamNotifier<MovieCollectionTypeChange> {
  Stream<MovieCollectionTypeChange> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<MovieCollectionTypeChange>,
              MovieCollectionTypeChange
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<MovieCollectionTypeChange>,
                MovieCollectionTypeChange
              >,
              AsyncValue<MovieCollectionTypeChange>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(MovieMediaEvents)
final movieMediaEventsProvider = MovieMediaEventsProvider._();

final class MovieMediaEventsProvider
    extends $StreamNotifierProvider<MovieMediaEvents, MovieMediaChange> {
  MovieMediaEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'movieMediaEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$movieMediaEventsHash();

  @$internal
  @override
  MovieMediaEvents create() => MovieMediaEvents();
}

String _$movieMediaEventsHash() => r'2f1294e4a0eda7826d29c479afed5ef5a8374696';

abstract class _$MovieMediaEvents extends $StreamNotifier<MovieMediaChange> {
  Stream<MovieMediaChange> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<MovieMediaChange>, MovieMediaChange>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MovieMediaChange>, MovieMediaChange>,
              AsyncValue<MovieMediaChange>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
