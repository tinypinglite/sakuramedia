// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_mutation_events_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// videos 域跨页变更广播 —— 与 `clipMutationEventsProvider` 同范式。
///
/// **消费方**：`ref.listen(videoMutationEventsProvider, (prev, next) {
/// final change = next.value; if (change != null) ...; })`；就地补丁。
///
/// **发起方**：`ref.read(videoMutationEventsProvider.notifier).reportDeleted(...)`
/// 或 `reportCollectionMembershipChanged(...)`。

@ProviderFor(VideoMutationEvents)
final videoMutationEventsProvider = VideoMutationEventsProvider._();

/// videos 域跨页变更广播 —— 与 `clipMutationEventsProvider` 同范式。
///
/// **消费方**：`ref.listen(videoMutationEventsProvider, (prev, next) {
/// final change = next.value; if (change != null) ...; })`；就地补丁。
///
/// **发起方**：`ref.read(videoMutationEventsProvider.notifier).reportDeleted(...)`
/// 或 `reportCollectionMembershipChanged(...)`。
final class VideoMutationEventsProvider
    extends $StreamNotifierProvider<VideoMutationEvents, VideoMutationChange> {
  /// videos 域跨页变更广播 —— 与 `clipMutationEventsProvider` 同范式。
  ///
  /// **消费方**：`ref.listen(videoMutationEventsProvider, (prev, next) {
  /// final change = next.value; if (change != null) ...; })`；就地补丁。
  ///
  /// **发起方**：`ref.read(videoMutationEventsProvider.notifier).reportDeleted(...)`
  /// 或 `reportCollectionMembershipChanged(...)`。
  VideoMutationEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoMutationEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoMutationEventsHash();

  @$internal
  @override
  VideoMutationEvents create() => VideoMutationEvents();
}

String _$videoMutationEventsHash() =>
    r'866b01aaef42b36de2173fbed56522cd9aa35f09';

/// videos 域跨页变更广播 —— 与 `clipMutationEventsProvider` 同范式。
///
/// **消费方**：`ref.listen(videoMutationEventsProvider, (prev, next) {
/// final change = next.value; if (change != null) ...; })`；就地补丁。
///
/// **发起方**：`ref.read(videoMutationEventsProvider.notifier).reportDeleted(...)`
/// 或 `reportCollectionMembershipChanged(...)`。

abstract class _$VideoMutationEvents
    extends $StreamNotifier<VideoMutationChange> {
  Stream<VideoMutationChange> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<VideoMutationChange>, VideoMutationChange>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VideoMutationChange>, VideoMutationChange>,
              AsyncValue<VideoMutationChange>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
