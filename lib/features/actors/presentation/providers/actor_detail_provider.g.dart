// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'actor_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 女优详情按 id 隔离，离开详情页后自动释放。

@ProviderFor(ActorDetail)
final actorDetailProvider = ActorDetailFamily._();

/// 女优详情按 id 隔离，离开详情页后自动释放。
final class ActorDetailProvider
    extends $AsyncNotifierProvider<ActorDetail, ActorDetailState> {
  /// 女优详情按 id 隔离，离开详情页后自动释放。
  ActorDetailProvider._({
    required ActorDetailFamily super.from,
    required int super.argument,
  }) : super(
         retry: kNoAsyncNotifierRetry,
         name: r'actorDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$actorDetailHash();

  @override
  String toString() {
    return r'actorDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ActorDetail create() => ActorDetail();

  @override
  bool operator ==(Object other) {
    return other is ActorDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$actorDetailHash() => r'143e378f8566ed47500ee1840f0ff00197b303c7';

/// 女优详情按 id 隔离，离开详情页后自动释放。

final class ActorDetailFamily extends $Family
    with
        $ClassFamilyOverride<
          ActorDetail,
          AsyncValue<ActorDetailState>,
          ActorDetailState,
          FutureOr<ActorDetailState>,
          int
        > {
  ActorDetailFamily._()
    : super(
        retry: kNoAsyncNotifierRetry,
        name: r'actorDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 女优详情按 id 隔离，离开详情页后自动释放。

  ActorDetailProvider call(int actorId) =>
      ActorDetailProvider._(argument: actorId, from: this);

  @override
  String toString() => r'actorDetailProvider';
}

/// 女优详情按 id 隔离，离开详情页后自动释放。

abstract class _$ActorDetail extends $AsyncNotifier<ActorDetailState> {
  late final _$args = ref.$arg as int;
  int get actorId => _$args;

  FutureOr<ActorDetailState> build(int actorId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ActorDetailState>, ActorDetailState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ActorDetailState>, ActorDetailState>,
              AsyncValue<ActorDetailState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
