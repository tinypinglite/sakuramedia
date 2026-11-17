// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'actor_removal_events_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 女优合并后跨页移除广播：通知列表把被合并掉的卡片摘掉。

@ProviderFor(ActorRemovalEvents)
final actorRemovalEventsProvider = ActorRemovalEventsProvider._();

/// 女优合并后跨页移除广播：通知列表把被合并掉的卡片摘掉。
final class ActorRemovalEventsProvider
    extends $StreamNotifierProvider<ActorRemovalEvents, List<int>> {
  /// 女优合并后跨页移除广播：通知列表把被合并掉的卡片摘掉。
  ActorRemovalEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'actorRemovalEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$actorRemovalEventsHash();

  @$internal
  @override
  ActorRemovalEvents create() => ActorRemovalEvents();
}

String _$actorRemovalEventsHash() =>
    r'b9cf1fb5aae5c213cd9ab9a57aecc3a9c5b4f9cf';

/// 女优合并后跨页移除广播：通知列表把被合并掉的卡片摘掉。

abstract class _$ActorRemovalEvents extends $StreamNotifier<List<int>> {
  Stream<List<int>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<int>>, List<int>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<int>>, List<int>>,
              AsyncValue<List<int>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
