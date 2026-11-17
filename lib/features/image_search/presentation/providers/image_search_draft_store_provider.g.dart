// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_search_draft_store_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 图搜草稿仓 [ImageSearchDraftStore] 的 Riverpod 入口。
///
/// 原生装配：组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(imageSearchDraftStore)
final imageSearchDraftStoreProvider = ImageSearchDraftStoreProvider._();

/// 图搜草稿仓 [ImageSearchDraftStore] 的 Riverpod 入口。
///
/// 原生装配：组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class ImageSearchDraftStoreProvider
    extends
        $FunctionalProvider<
          ImageSearchDraftStore,
          ImageSearchDraftStore,
          ImageSearchDraftStore
        >
    with $Provider<ImageSearchDraftStore> {
  /// 图搜草稿仓 [ImageSearchDraftStore] 的 Riverpod 入口。
  ///
  /// 原生装配：组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  ImageSearchDraftStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'imageSearchDraftStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$imageSearchDraftStoreHash();

  @$internal
  @override
  $ProviderElement<ImageSearchDraftStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ImageSearchDraftStore create(Ref ref) {
    return imageSearchDraftStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ImageSearchDraftStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ImageSearchDraftStore>(value),
    );
  }
}

String _$imageSearchDraftStoreHash() =>
    r'69b47dc582330a3cc76a89f0ae2f5ac84c449b74';
