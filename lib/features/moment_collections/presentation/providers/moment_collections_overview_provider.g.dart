// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moment_collections_overview_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MomentCollectionsOverview)
final momentCollectionsOverviewProvider = MomentCollectionsOverviewProvider._();

final class MomentCollectionsOverviewProvider
    extends
        $AsyncNotifierProvider<
          MomentCollectionsOverview,
          List<MomentCollectionDto>
        > {
  MomentCollectionsOverviewProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'momentCollectionsOverviewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$momentCollectionsOverviewHash();

  @$internal
  @override
  MomentCollectionsOverview create() => MomentCollectionsOverview();
}

String _$momentCollectionsOverviewHash() =>
    r'2616a8ec03b994c7a60d211abd2b769cdce022ff';

abstract class _$MomentCollectionsOverview
    extends $AsyncNotifier<List<MomentCollectionDto>> {
  FutureOr<List<MomentCollectionDto>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<MomentCollectionDto>>,
              List<MomentCollectionDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<MomentCollectionDto>>,
                List<MomentCollectionDto>
              >,
              AsyncValue<List<MomentCollectionDto>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
