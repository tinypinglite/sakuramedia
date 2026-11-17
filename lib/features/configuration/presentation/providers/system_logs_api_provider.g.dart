// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'system_logs_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(systemLogsApi)
final systemLogsApiProvider = SystemLogsApiProvider._();

final class SystemLogsApiProvider
    extends $FunctionalProvider<SystemLogsApi, SystemLogsApi, SystemLogsApi>
    with $Provider<SystemLogsApi> {
  SystemLogsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'systemLogsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$systemLogsApiHash();

  @$internal
  @override
  $ProviderElement<SystemLogsApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SystemLogsApi create(Ref ref) {
    return systemLogsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SystemLogsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SystemLogsApi>(value),
    );
  }
}

String _$systemLogsApiHash() => r'8fa2e4c03cc3a8dad8f049e37a70c3ac27f9b079';
