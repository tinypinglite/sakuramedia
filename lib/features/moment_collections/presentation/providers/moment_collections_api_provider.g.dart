// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moment_collections_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(momentCollectionsApi)
final momentCollectionsApiProvider = MomentCollectionsApiProvider._();

final class MomentCollectionsApiProvider
    extends
        $FunctionalProvider<
          MomentCollectionsApi,
          MomentCollectionsApi,
          MomentCollectionsApi
        >
    with $Provider<MomentCollectionsApi> {
  MomentCollectionsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'momentCollectionsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$momentCollectionsApiHash();

  @$internal
  @override
  $ProviderElement<MomentCollectionsApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MomentCollectionsApi create(Ref ref) {
    return momentCollectionsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MomentCollectionsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MomentCollectionsApi>(value),
    );
  }
}

String _$momentCollectionsApiHash() =>
    r'0c554ab3cc3f3153dddbbf957452225054dac771';
