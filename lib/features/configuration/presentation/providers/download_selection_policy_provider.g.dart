// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_selection_policy_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DownloadSelectionPolicy)
final downloadSelectionPolicyProvider = DownloadSelectionPolicyProvider._();

final class DownloadSelectionPolicyProvider
    extends
        $AsyncNotifierProvider<
          DownloadSelectionPolicy,
          DownloadSelectionPolicyState
        > {
  DownloadSelectionPolicyProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'downloadSelectionPolicyProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadSelectionPolicyHash();

  @$internal
  @override
  DownloadSelectionPolicy create() => DownloadSelectionPolicy();
}

String _$downloadSelectionPolicyHash() =>
    r'6ba6edce7c34904fec9c2953b4d369cebc025b7b';

abstract class _$DownloadSelectionPolicy
    extends $AsyncNotifier<DownloadSelectionPolicyState> {
  FutureOr<DownloadSelectionPolicyState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<DownloadSelectionPolicyState>,
              DownloadSelectionPolicyState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<DownloadSelectionPolicyState>,
                DownloadSelectionPolicyState
              >,
              AsyncValue<DownloadSelectionPolicyState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
