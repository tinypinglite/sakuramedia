// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_selection_policy_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(downloadSelectionPolicyApi)
final downloadSelectionPolicyApiProvider =
    DownloadSelectionPolicyApiProvider._();

final class DownloadSelectionPolicyApiProvider
    extends
        $FunctionalProvider<
          DownloadSelectionPolicyApi,
          DownloadSelectionPolicyApi,
          DownloadSelectionPolicyApi
        >
    with $Provider<DownloadSelectionPolicyApi> {
  DownloadSelectionPolicyApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadSelectionPolicyApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadSelectionPolicyApiHash();

  @$internal
  @override
  $ProviderElement<DownloadSelectionPolicyApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadSelectionPolicyApi create(Ref ref) {
    return downloadSelectionPolicyApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadSelectionPolicyApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadSelectionPolicyApi>(value),
    );
  }
}

String _$downloadSelectionPolicyApiHash() =>
    r'c9097330c1d19556c71da3b6cb4b8d49335c2164';
