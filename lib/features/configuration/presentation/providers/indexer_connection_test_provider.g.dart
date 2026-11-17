// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'indexer_connection_test_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 以组件 identity 隔离的 Torznab 测试状态，请求由调用方传入以支持草稿测试。

@ProviderFor(IndexerConnectionTest)
final indexerConnectionTestProvider = IndexerConnectionTestFamily._();

/// 以组件 identity 隔离的 Torznab 测试状态，请求由调用方传入以支持草稿测试。
final class IndexerConnectionTestProvider
    extends
        $NotifierProvider<IndexerConnectionTest, IndexerConnectionTestState> {
  /// 以组件 identity 隔离的 Torznab 测试状态，请求由调用方传入以支持草稿测试。
  IndexerConnectionTestProvider._({
    required IndexerConnectionTestFamily super.from,
    required Object super.argument,
  }) : super(
         retry: null,
         name: r'indexerConnectionTestProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$indexerConnectionTestHash();

  @override
  String toString() {
    return r'indexerConnectionTestProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  IndexerConnectionTest create() => IndexerConnectionTest();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IndexerConnectionTestState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IndexerConnectionTestState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IndexerConnectionTestProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$indexerConnectionTestHash() =>
    r'f540ef214cc4a0117d571852e57fdaf082b302c0';

/// 以组件 identity 隔离的 Torznab 测试状态，请求由调用方传入以支持草稿测试。

final class IndexerConnectionTestFamily extends $Family
    with
        $ClassFamilyOverride<
          IndexerConnectionTest,
          IndexerConnectionTestState,
          IndexerConnectionTestState,
          IndexerConnectionTestState,
          Object
        > {
  IndexerConnectionTestFamily._()
    : super(
        retry: null,
        name: r'indexerConnectionTestProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 以组件 identity 隔离的 Torznab 测试状态，请求由调用方传入以支持草稿测试。

  IndexerConnectionTestProvider call(Object scope) =>
      IndexerConnectionTestProvider._(argument: scope, from: this);

  @override
  String toString() => r'indexerConnectionTestProvider';
}

/// 以组件 identity 隔离的 Torznab 测试状态，请求由调用方传入以支持草稿测试。

abstract class _$IndexerConnectionTest
    extends $Notifier<IndexerConnectionTestState> {
  late final _$args = ref.$arg as Object;
  Object get scope => _$args;

  IndexerConnectionTestState build(Object scope);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<IndexerConnectionTestState, IndexerConnectionTestState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                IndexerConnectionTestState,
                IndexerConnectionTestState
              >,
              IndexerConnectionTestState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
