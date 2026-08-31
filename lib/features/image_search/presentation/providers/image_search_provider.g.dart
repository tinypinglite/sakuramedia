// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 按完整路由 location 隔离、由页面 LRU 缓存保活的图搜状态源。

@ProviderFor(ImageSearch)
final imageSearchProvider = ImageSearchFamily._();

/// 按完整路由 location 隔离、由页面 LRU 缓存保活的图搜状态源。
final class ImageSearchProvider
    extends $NotifierProvider<ImageSearch, ImageSearchState> {
  /// 按完整路由 location 隔离、由页面 LRU 缓存保活的图搜状态源。
  ImageSearchProvider._({
    required ImageSearchFamily super.from,
    required ImageSearchScope super.argument,
  }) : super(
         retry: null,
         name: r'imageSearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$imageSearchHash();

  @override
  String toString() {
    return r'imageSearchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ImageSearch create() => ImageSearch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImageSearchState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImageSearchState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ImageSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$imageSearchHash() => r'4c95292b7178fc6b6b3a563a85e46463a5f0c84c';

/// 按完整路由 location 隔离、由页面 LRU 缓存保活的图搜状态源。

final class ImageSearchFamily extends $Family
    with
        $ClassFamilyOverride<
          ImageSearch,
          ImageSearchState,
          ImageSearchState,
          ImageSearchState,
          ImageSearchScope
        > {
  ImageSearchFamily._()
    : super(
        retry: null,
        name: r'imageSearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 按完整路由 location 隔离、由页面 LRU 缓存保活的图搜状态源。

  ImageSearchProvider call(ImageSearchScope scope) =>
      ImageSearchProvider._(argument: scope, from: this);

  @override
  String toString() => r'imageSearchProvider';
}

/// 按完整路由 location 隔离、由页面 LRU 缓存保活的图搜状态源。

abstract class _$ImageSearch extends $Notifier<ImageSearchState> {
  late final _$args = ref.$arg as ImageSearchScope;
  ImageSearchScope get scope => _$args;

  ImageSearchState build(ImageSearchScope scope);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ImageSearchState, ImageSearchState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ImageSearchState, ImageSearchState>,
              ImageSearchState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
