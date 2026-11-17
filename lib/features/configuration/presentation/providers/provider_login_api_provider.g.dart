// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_login_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(providerLoginApi)
final providerLoginApiProvider = ProviderLoginApiProvider._();

final class ProviderLoginApiProvider
    extends
        $FunctionalProvider<
          ProviderLoginApi,
          ProviderLoginApi,
          ProviderLoginApi
        >
    with $Provider<ProviderLoginApi> {
  ProviderLoginApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'providerLoginApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$providerLoginApiHash();

  @$internal
  @override
  $ProviderElement<ProviderLoginApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ProviderLoginApi create(Ref ref) {
    return providerLoginApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProviderLoginApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProviderLoginApi>(value),
    );
  }
}

String _$providerLoginApiHash() => r'5c0a21f11b7a71e819706c3b0b4f43b5ee04a228';
