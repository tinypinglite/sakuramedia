// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// account 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(accountApi)
final accountApiProvider = AccountApiProvider._();

/// account 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class AccountApiProvider
    extends $FunctionalProvider<AccountApi, AccountApi, AccountApi>
    with $Provider<AccountApi> {
  /// account 域 API 的 Riverpod 入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  AccountApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountApiHash();

  @$internal
  @override
  $ProviderElement<AccountApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AccountApi create(Ref ref) {
    return accountApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountApi>(value),
    );
  }
}

String _$accountApiHash() => r'9b4c06495a182892c41ff7226c2983b6633c3cdf';
