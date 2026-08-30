// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloads_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// downloads feature 读取 API 的入口。

@ProviderFor(downloadsApi)
final downloadsApiProvider = DownloadsApiProvider._();

/// downloads feature 读取 API 的入口。

final class DownloadsApiProvider
    extends $FunctionalProvider<DownloadsApi, DownloadsApi, DownloadsApi>
    with $Provider<DownloadsApi> {
  /// downloads feature 读取 API 的入口。
  DownloadsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadsApiHash();

  @$internal
  @override
  $ProviderElement<DownloadsApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DownloadsApi create(Ref ref) {
    return downloadsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadsApi>(value),
    );
  }
}

String _$downloadsApiHash() => r'c8fe9abf2d2ca289d6e289cff249614fc2ad5eb3';

/// 下载客户端配置 API 的桥接：下载中心需要客户端列表用于筛选下拉与名称映射。

@ProviderFor(downloadClientsApi)
final downloadClientsApiProvider = DownloadClientsApiProvider._();

/// 下载客户端配置 API 的桥接：下载中心需要客户端列表用于筛选下拉与名称映射。

final class DownloadClientsApiProvider
    extends
        $FunctionalProvider<
          DownloadClientsApi,
          DownloadClientsApi,
          DownloadClientsApi
        >
    with $Provider<DownloadClientsApi> {
  /// 下载客户端配置 API 的桥接：下载中心需要客户端列表用于筛选下拉与名称映射。
  DownloadClientsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'downloadClientsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadClientsApiHash();

  @$internal
  @override
  $ProviderElement<DownloadClientsApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DownloadClientsApi create(Ref ref) {
    return downloadClientsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadClientsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadClientsApi>(value),
    );
  }
}

String _$downloadClientsApiHash() =>
    r'600e51c3399f3b69d9759783804aa51357609557';
