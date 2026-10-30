// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// auth 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖（[ApiClient] / [SessionStore] / [CredentialStore]）经
/// `ref.watch` 拉取，组合根不再 override。测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(authApi)
final authApiProvider = AuthApiProvider._();

/// auth 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖（[ApiClient] / [SessionStore] / [CredentialStore]）经
/// `ref.watch` 拉取，组合根不再 override。测试需要替身时用 `overrideWithValue(...)`。

final class AuthApiProvider
    extends $FunctionalProvider<AuthApi, AuthApi, AuthApi>
    with $Provider<AuthApi> {
  /// auth 域 API 的 Riverpod 入口。
  ///
  /// 原生装配：依赖（[ApiClient] / [SessionStore] / [CredentialStore]）经
  /// `ref.watch` 拉取，组合根不再 override。测试需要替身时用 `overrideWithValue(...)`。
  AuthApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authApiHash();

  @$internal
  @override
  $ProviderElement<AuthApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthApi create(Ref ref) {
    return authApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthApi>(value),
    );
  }
}

String _$authApiHash() => r'ec17dae03b3a458ca403ef071c040499d77fe1a6';
