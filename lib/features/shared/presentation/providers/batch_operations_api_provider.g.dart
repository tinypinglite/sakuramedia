// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'batch_operations_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 批量操作任务提交 API 的统一入口。

@ProviderFor(batchOperationsApi)
final batchOperationsApiProvider = BatchOperationsApiProvider._();

/// 批量操作任务提交 API 的统一入口。

final class BatchOperationsApiProvider
    extends
        $FunctionalProvider<
          BatchOperationsApi,
          BatchOperationsApi,
          BatchOperationsApi
        >
    with $Provider<BatchOperationsApi> {
  /// 批量操作任务提交 API 的统一入口。
  BatchOperationsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'batchOperationsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$batchOperationsApiHash();

  @$internal
  @override
  $ProviderElement<BatchOperationsApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BatchOperationsApi create(Ref ref) {
    return batchOperationsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BatchOperationsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BatchOperationsApi>(value),
    );
  }
}

String _$batchOperationsApiHash() =>
    r'42eb6ed197b4a4ba69c3552cea54807dfd300fe1';
