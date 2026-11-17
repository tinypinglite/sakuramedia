// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'riverpod_page_cache_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 全局 [RiverpodPageCache] 的 Riverpod 入口。
///
/// 原生装配：构造即 `bindSessionStore`（登出自动全清）。cache 本身
/// keepAlive 常驻——它
/// 持有的只是「link 句柄」而非业务状态，业务 provider 的释放由 link close
/// 触发，cache 常驻不会泄漏任何列表数据。

@ProviderFor(riverpodPageCache)
final riverpodPageCacheProvider = RiverpodPageCacheProvider._();

/// 全局 [RiverpodPageCache] 的 Riverpod 入口。
///
/// 原生装配：构造即 `bindSessionStore`（登出自动全清）。cache 本身
/// keepAlive 常驻——它
/// 持有的只是「link 句柄」而非业务状态，业务 provider 的释放由 link close
/// 触发，cache 常驻不会泄漏任何列表数据。

final class RiverpodPageCacheProvider
    extends
        $FunctionalProvider<
          RiverpodPageCache,
          RiverpodPageCache,
          RiverpodPageCache
        >
    with $Provider<RiverpodPageCache> {
  /// 全局 [RiverpodPageCache] 的 Riverpod 入口。
  ///
  /// 原生装配：构造即 `bindSessionStore`（登出自动全清）。cache 本身
  /// keepAlive 常驻——它
  /// 持有的只是「link 句柄」而非业务状态，业务 provider 的释放由 link close
  /// 触发，cache 常驻不会泄漏任何列表数据。
  RiverpodPageCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'riverpodPageCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$riverpodPageCacheHash();

  @$internal
  @override
  $ProviderElement<RiverpodPageCache> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RiverpodPageCache create(Ref ref) {
    return riverpodPageCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RiverpodPageCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RiverpodPageCache>(value),
    );
  }
}

String _$riverpodPageCacheHash() => r'a85f3a2c3c574454145b9cab4263b04d443681fe';
