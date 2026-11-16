// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'indexer_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 索引器设置的共享远端快照与桌面草稿。
///
/// 下载器列表由 [downloadClientsProvider] 独立提供，避免下载器更新时重建并丢弃
/// 尚未保存的索引器草稿。

@ProviderFor(IndexerSettings)
final indexerSettingsProvider = IndexerSettingsProvider._();

/// 索引器设置的共享远端快照与桌面草稿。
///
/// 下载器列表由 [downloadClientsProvider] 独立提供，避免下载器更新时重建并丢弃
/// 尚未保存的索引器草稿。
final class IndexerSettingsProvider
    extends $AsyncNotifierProvider<IndexerSettings, IndexerSettingsState> {
  /// 索引器设置的共享远端快照与桌面草稿。
  ///
  /// 下载器列表由 [downloadClientsProvider] 独立提供，避免下载器更新时重建并丢弃
  /// 尚未保存的索引器草稿。
  IndexerSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'indexerSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$indexerSettingsHash();

  @$internal
  @override
  IndexerSettings create() => IndexerSettings();
}

String _$indexerSettingsHash() => r'7720bc54abaa84acc68050ee0e0e3ca0a5bc227a';

/// 索引器设置的共享远端快照与桌面草稿。
///
/// 下载器列表由 [downloadClientsProvider] 独立提供，避免下载器更新时重建并丢弃
/// 尚未保存的索引器草稿。

abstract class _$IndexerSettings extends $AsyncNotifier<IndexerSettingsState> {
  FutureOr<IndexerSettingsState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<IndexerSettingsState>, IndexerSettingsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<IndexerSettingsState>,
                IndexerSettingsState
              >,
              AsyncValue<IndexerSettingsState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
