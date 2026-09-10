// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moment_collection_mutation_events_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 时刻合集跨页变更广播；监听方重新读取合集摘要以同步数量和封面。

@ProviderFor(MomentCollectionMutationEvents)
final momentCollectionMutationEventsProvider =
    MomentCollectionMutationEventsProvider._();

/// 时刻合集跨页变更广播；监听方重新读取合集摘要以同步数量和封面。
final class MomentCollectionMutationEventsProvider
    extends $StreamNotifierProvider<MomentCollectionMutationEvents, int> {
  /// 时刻合集跨页变更广播；监听方重新读取合集摘要以同步数量和封面。
  MomentCollectionMutationEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'momentCollectionMutationEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$momentCollectionMutationEventsHash();

  @$internal
  @override
  MomentCollectionMutationEvents create() => MomentCollectionMutationEvents();
}

String _$momentCollectionMutationEventsHash() =>
    r'ca4158825448201677fd4056364937799385ecad';

/// 时刻合集跨页变更广播；监听方重新读取合集摘要以同步数量和封面。

abstract class _$MomentCollectionMutationEvents extends $StreamNotifier<int> {
  Stream<int> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<int>, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<int>, int>,
              AsyncValue<int>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
