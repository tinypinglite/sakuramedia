// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 全局 [ApiClient] 的 Riverpod 入口。
///
/// 原生装配：依赖（[SessionStore]）经 `ref.watch` 拉取，组合根不再 override。
/// 语言头用回调在每次请求时读取，避免切语言重建 client、中断 SSE/在飞请求。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(apiClient)
final apiClientProvider = ApiClientProvider._();

/// 全局 [ApiClient] 的 Riverpod 入口。
///
/// 原生装配：依赖（[SessionStore]）经 `ref.watch` 拉取，组合根不再 override。
/// 语言头用回调在每次请求时读取，避免切语言重建 client、中断 SSE/在飞请求。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class ApiClientProvider
    extends $FunctionalProvider<ApiClient, ApiClient, ApiClient>
    with $Provider<ApiClient> {
  /// 全局 [ApiClient] 的 Riverpod 入口。
  ///
  /// 原生装配：依赖（[SessionStore]）经 `ref.watch` 拉取，组合根不再 override。
  /// 语言头用回调在每次请求时读取，避免切语言重建 client、中断 SSE/在飞请求。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  ApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiClientHash();

  @$internal
  @override
  $ProviderElement<ApiClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ApiClient create(Ref ref) {
    return apiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApiClient>(value),
    );
  }
}

String _$apiClientHash() => r'0363eca78410e2912b098067b0d6fae31c96f367';
