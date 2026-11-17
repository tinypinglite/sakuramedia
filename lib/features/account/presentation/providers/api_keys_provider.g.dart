// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_keys_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// API 密钥列表：生成/删除后就地更新状态，不整表重拉。

@ProviderFor(ApiKeys)
final apiKeysProvider = ApiKeysProvider._();

/// API 密钥列表：生成/删除后就地更新状态，不整表重拉。
final class ApiKeysProvider
    extends $AsyncNotifierProvider<ApiKeys, List<ApiKeyDto>> {
  /// API 密钥列表：生成/删除后就地更新状态，不整表重拉。
  ApiKeysProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiKeysProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiKeysHash();

  @$internal
  @override
  ApiKeys create() => ApiKeys();
}

String _$apiKeysHash() => r'ee39536896438cab48b3445a522dbbd19e386121';

/// API 密钥列表：生成/删除后就地更新状态，不整表重拉。

abstract class _$ApiKeys extends $AsyncNotifier<List<ApiKeyDto>> {
  FutureOr<List<ApiKeyDto>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<ApiKeyDto>>, List<ApiKeyDto>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<ApiKeyDto>>, List<ApiKeyDto>>,
              AsyncValue<List<ApiKeyDto>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
