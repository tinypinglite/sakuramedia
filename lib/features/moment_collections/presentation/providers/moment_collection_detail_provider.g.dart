// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moment_collection_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MomentCollectionDetail)
final momentCollectionDetailProvider = MomentCollectionDetailFamily._();

final class MomentCollectionDetailProvider
    extends
        $AsyncNotifierProvider<
          MomentCollectionDetail,
          MomentCollectionDetailState
        > {
  MomentCollectionDetailProvider._({
    required MomentCollectionDetailFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'momentCollectionDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$momentCollectionDetailHash();

  @override
  String toString() {
    return r'momentCollectionDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MomentCollectionDetail create() => MomentCollectionDetail();

  @override
  bool operator ==(Object other) {
    return other is MomentCollectionDetailProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$momentCollectionDetailHash() =>
    r'5e230888029505639385106fd46d670a0440cc28';

final class MomentCollectionDetailFamily extends $Family
    with
        $ClassFamilyOverride<
          MomentCollectionDetail,
          AsyncValue<MomentCollectionDetailState>,
          MomentCollectionDetailState,
          FutureOr<MomentCollectionDetailState>,
          int
        > {
  MomentCollectionDetailFamily._()
    : super(
        retry: null,
        name: r'momentCollectionDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MomentCollectionDetailProvider call(int collectionId) =>
      MomentCollectionDetailProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'momentCollectionDetailProvider';
}

abstract class _$MomentCollectionDetail
    extends $AsyncNotifier<MomentCollectionDetailState> {
  late final _$args = ref.$arg as int;
  int get collectionId => _$args;

  FutureOr<MomentCollectionDetailState> build(int collectionId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<MomentCollectionDetailState>,
              MomentCollectionDetailState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<MomentCollectionDetailState>,
                MomentCollectionDetailState
              >,
              AsyncValue<MomentCollectionDetailState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
