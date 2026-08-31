// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtitle_import_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 字幕导入 API 的 Riverpod 入口。

@ProviderFor(subtitleImportApi)
final subtitleImportApiProvider = SubtitleImportApiProvider._();

/// 字幕导入 API 的 Riverpod 入口。

final class SubtitleImportApiProvider
    extends
        $FunctionalProvider<
          SubtitleImportApi,
          SubtitleImportApi,
          SubtitleImportApi
        >
    with $Provider<SubtitleImportApi> {
  /// 字幕导入 API 的 Riverpod 入口。
  SubtitleImportApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subtitleImportApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subtitleImportApiHash();

  @$internal
  @override
  $ProviderElement<SubtitleImportApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SubtitleImportApi create(Ref ref) {
    return subtitleImportApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubtitleImportApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubtitleImportApi>(value),
    );
  }
}

String _$subtitleImportApiHash() => r'20f6f3eaa4398d90f7df2a085fbd26562c32285a';
