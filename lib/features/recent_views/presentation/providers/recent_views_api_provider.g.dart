// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recent_views_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// recent_views 域 API 的 Riverpod 入口。

@ProviderFor(recentViewsApi)
final recentViewsApiProvider = RecentViewsApiProvider._();

/// recent_views 域 API 的 Riverpod 入口。

final class RecentViewsApiProvider
    extends $FunctionalProvider<RecentViewsApi, RecentViewsApi, RecentViewsApi>
    with $Provider<RecentViewsApi> {
  /// recent_views 域 API 的 Riverpod 入口。
  RecentViewsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentViewsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentViewsApiHash();

  @$internal
  @override
  $ProviderElement<RecentViewsApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RecentViewsApi create(Ref ref) {
    return recentViewsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecentViewsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecentViewsApi>(value),
    );
  }
}

String _$recentViewsApiHash() => r'076bf696072c19bd55215ca988027523196ca4c2';
