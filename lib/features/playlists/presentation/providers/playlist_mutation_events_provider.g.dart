// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_mutation_events_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 播放列表跨页变更广播 —— 与 `videoMutationEventsProvider` 同范式。
///
/// **消费方**：`ref.listen(playlistMutationEventsProvider, (prev, next) {
/// final change = next.value; if (change != null) ...; })` 就地补丁。
///
/// **发起方**：详情页编辑/删除后 `reportUpdated` / `reportDeleted`。

@ProviderFor(PlaylistMutationEvents)
final playlistMutationEventsProvider = PlaylistMutationEventsProvider._();

/// 播放列表跨页变更广播 —— 与 `videoMutationEventsProvider` 同范式。
///
/// **消费方**：`ref.listen(playlistMutationEventsProvider, (prev, next) {
/// final change = next.value; if (change != null) ...; })` 就地补丁。
///
/// **发起方**：详情页编辑/删除后 `reportUpdated` / `reportDeleted`。
final class PlaylistMutationEventsProvider
    extends
        $StreamNotifierProvider<
          PlaylistMutationEvents,
          PlaylistMutationChange
        > {
  /// 播放列表跨页变更广播 —— 与 `videoMutationEventsProvider` 同范式。
  ///
  /// **消费方**：`ref.listen(playlistMutationEventsProvider, (prev, next) {
  /// final change = next.value; if (change != null) ...; })` 就地补丁。
  ///
  /// **发起方**：详情页编辑/删除后 `reportUpdated` / `reportDeleted`。
  PlaylistMutationEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playlistMutationEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playlistMutationEventsHash();

  @$internal
  @override
  PlaylistMutationEvents create() => PlaylistMutationEvents();
}

String _$playlistMutationEventsHash() =>
    r'0bc511a7bb32a9556acb8cc565d7daf4e3827cb6';

/// 播放列表跨页变更广播 —— 与 `videoMutationEventsProvider` 同范式。
///
/// **消费方**：`ref.listen(playlistMutationEventsProvider, (prev, next) {
/// final change = next.value; if (change != null) ...; })` 就地补丁。
///
/// **发起方**：详情页编辑/删除后 `reportUpdated` / `reportDeleted`。

abstract class _$PlaylistMutationEvents
    extends $StreamNotifier<PlaylistMutationChange> {
  Stream<PlaylistMutationChange> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<PlaylistMutationChange>, PlaylistMutationChange>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<PlaylistMutationChange>,
                PlaylistMutationChange
              >,
              AsyncValue<PlaylistMutationChange>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
