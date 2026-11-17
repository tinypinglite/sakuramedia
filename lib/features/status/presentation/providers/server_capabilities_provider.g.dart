// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_capabilities_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(serverCapabilities)
final serverCapabilitiesProvider = ServerCapabilitiesProvider._();

final class ServerCapabilitiesProvider
    extends
        $FunctionalProvider<
          AsyncValue<ServerCapabilities>,
          ServerCapabilities,
          FutureOr<ServerCapabilities>
        >
    with
        $FutureModifier<ServerCapabilities>,
        $FutureProvider<ServerCapabilities> {
  ServerCapabilitiesProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'serverCapabilitiesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverCapabilitiesHash();

  @$internal
  @override
  $FutureProviderElement<ServerCapabilities> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ServerCapabilities> create(Ref ref) {
    return serverCapabilities(ref);
  }
}

String _$serverCapabilitiesHash() =>
    r'81294e752dc195a2e05d36fd45c3192ed9499dc0';

@ProviderFor(imageSearchEnabled)
final imageSearchEnabledProvider = ImageSearchEnabledProvider._();

final class ImageSearchEnabledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  ImageSearchEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imageSearchEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imageSearchEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return imageSearchEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$imageSearchEnabledHash() =>
    r'938eaa677c77c8a8a1555eb24e9f93d147ca75f3';

@ProviderFor(movieSimilarityEnabled)
final movieSimilarityEnabledProvider = MovieSimilarityEnabledProvider._();

final class MovieSimilarityEnabledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  MovieSimilarityEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'movieSimilarityEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$movieSimilarityEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return movieSimilarityEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$movieSimilarityEnabledHash() =>
    r'cb15b846662bc52cf15323de8a5ab804cd57de19';
