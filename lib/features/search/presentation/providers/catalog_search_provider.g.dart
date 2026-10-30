// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 一次性目录搜索的按路由缓存状态。
///
/// 这里刻意不把 SSE 搜索套入通用事件流：每个 provider 实例只拥有一条可取消的
/// 搜索流，并以版本号丢弃旧查询的迟到回包，逐项复刻原控制器的竞态语义。

@ProviderFor(CatalogSearch)
final catalogSearchProvider = CatalogSearchFamily._();

/// 一次性目录搜索的按路由缓存状态。
///
/// 这里刻意不把 SSE 搜索套入通用事件流：每个 provider 实例只拥有一条可取消的
/// 搜索流，并以版本号丢弃旧查询的迟到回包，逐项复刻原控制器的竞态语义。
final class CatalogSearchProvider
    extends $NotifierProvider<CatalogSearch, CatalogSearchState> {
  /// 一次性目录搜索的按路由缓存状态。
  ///
  /// 这里刻意不把 SSE 搜索套入通用事件流：每个 provider 实例只拥有一条可取消的
  /// 搜索流，并以版本号丢弃旧查询的迟到回包，逐项复刻原控制器的竞态语义。
  CatalogSearchProvider._({
    required CatalogSearchFamily super.from,
    required CatalogSearchScope super.argument,
  }) : super(
         retry: null,
         name: r'catalogSearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$catalogSearchHash();

  @override
  String toString() {
    return r'catalogSearchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CatalogSearch create() => CatalogSearch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CatalogSearchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CatalogSearchState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CatalogSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$catalogSearchHash() => r'3dc2b5bf04e8354fd413bb35c0eacc6ab66971e6';

/// 一次性目录搜索的按路由缓存状态。
///
/// 这里刻意不把 SSE 搜索套入通用事件流：每个 provider 实例只拥有一条可取消的
/// 搜索流，并以版本号丢弃旧查询的迟到回包，逐项复刻原控制器的竞态语义。

final class CatalogSearchFamily extends $Family
    with
        $ClassFamilyOverride<
          CatalogSearch,
          CatalogSearchState,
          CatalogSearchState,
          CatalogSearchState,
          CatalogSearchScope
        > {
  CatalogSearchFamily._()
    : super(
        retry: null,
        name: r'catalogSearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 一次性目录搜索的按路由缓存状态。
  ///
  /// 这里刻意不把 SSE 搜索套入通用事件流：每个 provider 实例只拥有一条可取消的
  /// 搜索流，并以版本号丢弃旧查询的迟到回包，逐项复刻原控制器的竞态语义。

  CatalogSearchProvider call(CatalogSearchScope scope) =>
      CatalogSearchProvider._(argument: scope, from: this);

  @override
  String toString() => r'catalogSearchProvider';
}

/// 一次性目录搜索的按路由缓存状态。
///
/// 这里刻意不把 SSE 搜索套入通用事件流：每个 provider 实例只拥有一条可取消的
/// 搜索流，并以版本号丢弃旧查询的迟到回包，逐项复刻原控制器的竞态语义。

abstract class _$CatalogSearch extends $Notifier<CatalogSearchState> {
  late final _$args = ref.$arg as CatalogSearchScope;
  CatalogSearchScope get scope => _$args;

  CatalogSearchState build(CatalogSearchScope scope);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CatalogSearchState, CatalogSearchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CatalogSearchState, CatalogSearchState>,
              CatalogSearchState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
