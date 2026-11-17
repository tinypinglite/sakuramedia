// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'credential_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 全局 [CredentialStore] 的 Riverpod 入口。
///
/// 原生装配：body 直接构造，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(credentialStore)
final credentialStoreProvider = CredentialStoreProvider._();

/// 全局 [CredentialStore] 的 Riverpod 入口。
///
/// 原生装配：body 直接构造，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class CredentialStoreProvider
    extends
        $FunctionalProvider<CredentialStore, CredentialStore, CredentialStore>
    with $Provider<CredentialStore> {
  /// 全局 [CredentialStore] 的 Riverpod 入口。
  ///
  /// 原生装配：body 直接构造，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  CredentialStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'credentialStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$credentialStoreHash();

  @$internal
  @override
  $ProviderElement<CredentialStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CredentialStore create(Ref ref) {
    return credentialStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CredentialStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CredentialStore>(value),
    );
  }
}

String _$credentialStoreHash() => r'aa7619944af1e79b2c9930fe91383255c45eeb18';
