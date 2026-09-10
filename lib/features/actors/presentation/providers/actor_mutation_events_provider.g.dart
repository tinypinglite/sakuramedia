// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'actor_mutation_events_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 演员资料跨页变更广播。

@ProviderFor(ActorMutationEvents)
final actorMutationEventsProvider = ActorMutationEventsProvider._();

/// 演员资料跨页变更广播。
final class ActorMutationEventsProvider
    extends $StreamNotifierProvider<ActorMutationEvents, ActorListItemDto> {
  /// 演员资料跨页变更广播。
  ActorMutationEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'actorMutationEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$actorMutationEventsHash();

  @$internal
  @override
  ActorMutationEvents create() => ActorMutationEvents();
}

String _$actorMutationEventsHash() =>
    r'fae01e7441831f26e769cfe7938302eea856c563';

/// 演员资料跨页变更广播。

abstract class _$ActorMutationEvents extends $StreamNotifier<ActorListItemDto> {
  Stream<ActorListItemDto> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ActorListItemDto>, ActorListItemDto>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ActorListItemDto>, ActorListItemDto>,
              AsyncValue<ActorListItemDto>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
