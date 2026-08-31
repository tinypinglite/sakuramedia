// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloads_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// downloads feature Riverpod Notifier 读 API 的入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(downloadsApi)
final downloadsApiProvider = DownloadsApiProvider._();

/// downloads feature Riverpod Notifier 读 API 的入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class DownloadsApiProvider
    extends $FunctionalProvider<DownloadsApi, DownloadsApi, DownloadsApi>
    with $Provider<DownloadsApi> {
  /// downloads feature Riverpod Notifier 读 API 的入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
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

String _$downloadsApiHash() => r'a164c06ff9f605afd85f0e5d18a4c63afd3091fa';

/// 下载客户端配置 API 的桥接：下载中心需要读客户端列表用于筛选下拉与名称/kind 映射。
///
/// `DownloadClientsApi` 归属 configuration 域；先在 downloads 侧建 bridge，等
/// configuration 迁 Riverpod 时再上移。

@ProviderFor(downloadClientsApi)
final downloadClientsApiProvider = DownloadClientsApiProvider._();

/// 下载客户端配置 API 的桥接：下载中心需要读客户端列表用于筛选下拉与名称/kind 映射。
///
/// `DownloadClientsApi` 归属 configuration 域；先在 downloads 侧建 bridge，等
/// configuration 迁 Riverpod 时再上移。

final class DownloadClientsApiProvider
    extends
        $FunctionalProvider<
          DownloadClientsApi,
          DownloadClientsApi,
          DownloadClientsApi
        >
    with $Provider<DownloadClientsApi> {
  /// 下载客户端配置 API 的桥接：下载中心需要读客户端列表用于筛选下拉与名称/kind 映射。
  ///
  /// `DownloadClientsApi` 归属 configuration 域；先在 downloads 侧建 bridge，等
  /// configuration 迁 Riverpod 时再上移。
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
