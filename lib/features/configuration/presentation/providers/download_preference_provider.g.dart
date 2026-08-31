// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_preference_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DownloadPreference)
final downloadPreferenceProvider = DownloadPreferenceProvider._();

final class DownloadPreferenceProvider
    extends
        $AsyncNotifierProvider<DownloadPreference, DownloadPreferenceState> {
  DownloadPreferenceProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'downloadPreferenceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadPreferenceHash();

  @$internal
  @override
  DownloadPreference create() => DownloadPreference();
}

String _$downloadPreferenceHash() =>
    r'fb8ba0a44956116ccbea4351a106931302491334';

abstract class _$DownloadPreference
    extends $AsyncNotifier<DownloadPreferenceState> {
  FutureOr<DownloadPreferenceState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<DownloadPreferenceState>,
              DownloadPreferenceState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<DownloadPreferenceState>,
                DownloadPreferenceState
              >,
              AsyncValue<DownloadPreferenceState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
