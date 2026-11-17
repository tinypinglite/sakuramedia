// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clip_mutation_events_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 切片跨页变更广播 —— 与 `movieSubscriptionEventsProvider` 同范式：
/// 单一 provider 同时承载事件流与发布 API。
///
/// **消费方**：`ref.listen(clipMutationEventsProvider, (prev, next) {
/// final change = next.value; if (change != null) ...; })`；就地补丁，不整页重拉。
///
/// **发起方**：`ref.read(clipMutationEventsProvider.notifier).reportDeleted(...)`
/// 或 `reportCollectionMembershipChanged(...)`。
///
/// 与 videos 的 [videoMutationEventsProvider] 同构；由于切片合集详情还支持拖序与
/// 改名，这些同样归入 [ClipMutationKind.collectionMembershipChanged]，由监听方
/// 重拉合集列表校准。

@ProviderFor(ClipMutationEvents)
final clipMutationEventsProvider = ClipMutationEventsProvider._();

/// 切片跨页变更广播 —— 与 `movieSubscriptionEventsProvider` 同范式：
/// 单一 provider 同时承载事件流与发布 API。
///
/// **消费方**：`ref.listen(clipMutationEventsProvider, (prev, next) {
/// final change = next.value; if (change != null) ...; })`；就地补丁，不整页重拉。
///
/// **发起方**：`ref.read(clipMutationEventsProvider.notifier).reportDeleted(...)`
/// 或 `reportCollectionMembershipChanged(...)`。
///
/// 与 videos 的 [videoMutationEventsProvider] 同构；由于切片合集详情还支持拖序与
/// 改名，这些同样归入 [ClipMutationKind.collectionMembershipChanged]，由监听方
/// 重拉合集列表校准。
final class ClipMutationEventsProvider
    extends $StreamNotifierProvider<ClipMutationEvents, ClipMutationChange> {
  /// 切片跨页变更广播 —— 与 `movieSubscriptionEventsProvider` 同范式：
  /// 单一 provider 同时承载事件流与发布 API。
  ///
  /// **消费方**：`ref.listen(clipMutationEventsProvider, (prev, next) {
  /// final change = next.value; if (change != null) ...; })`；就地补丁，不整页重拉。
  ///
  /// **发起方**：`ref.read(clipMutationEventsProvider.notifier).reportDeleted(...)`
  /// 或 `reportCollectionMembershipChanged(...)`。
  ///
  /// 与 videos 的 [videoMutationEventsProvider] 同构；由于切片合集详情还支持拖序与
  /// 改名，这些同样归入 [ClipMutationKind.collectionMembershipChanged]，由监听方
  /// 重拉合集列表校准。
  ClipMutationEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clipMutationEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clipMutationEventsHash();

  @$internal
  @override
  ClipMutationEvents create() => ClipMutationEvents();
}

String _$clipMutationEventsHash() =>
    r'75bec8f3b317cd26a74e7e685ea9fcc56bf48eef';

/// 切片跨页变更广播 —— 与 `movieSubscriptionEventsProvider` 同范式：
/// 单一 provider 同时承载事件流与发布 API。
///
/// **消费方**：`ref.listen(clipMutationEventsProvider, (prev, next) {
/// final change = next.value; if (change != null) ...; })`；就地补丁，不整页重拉。
///
/// **发起方**：`ref.read(clipMutationEventsProvider.notifier).reportDeleted(...)`
/// 或 `reportCollectionMembershipChanged(...)`。
///
/// 与 videos 的 [videoMutationEventsProvider] 同构；由于切片合集详情还支持拖序与
/// 改名，这些同样归入 [ClipMutationKind.collectionMembershipChanged]，由监听方
/// 重拉合集列表校准。

abstract class _$ClipMutationEvents
    extends $StreamNotifier<ClipMutationChange> {
  Stream<ClipMutationChange> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ClipMutationChange>, ClipMutationChange>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ClipMutationChange>, ClipMutationChange>,
              AsyncValue<ClipMutationChange>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
