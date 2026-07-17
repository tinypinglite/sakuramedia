// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'downloads_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// downloads feature Riverpod Notifier 读 API 的入口。
///
/// body 抛 [UnimplementedError]，实际实例由 `lib/app/app.dart` 的组合根
/// 用 `overrideWithValue(context.read<DownloadsApi>())` 注入。

@ProviderFor(downloadsApi)
final downloadsApiProvider = DownloadsApiProvider._();

/// downloads feature Riverpod Notifier 读 API 的入口。
///
/// body 抛 [UnimplementedError]，实际实例由 `lib/app/app.dart` 的组合根
/// 用 `overrideWithValue(context.read<DownloadsApi>())` 注入。

final class DownloadsApiProvider
    extends $FunctionalProvider<DownloadsApi, DownloadsApi, DownloadsApi>
    with $Provider<DownloadsApi> {
  /// downloads feature Riverpod Notifier 读 API 的入口。
  ///
  /// body 抛 [UnimplementedError]，实际实例由 `lib/app/app.dart` 的组合根
  /// 用 `overrideWithValue(context.read<DownloadsApi>())` 注入。
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

String _$downloadsApiHash() => r'4837656ec6b6e12e8f6caccf274e223fd2f05067';

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
    r'a77f4213a1d48b78c5314b4d92bb27bf43650fca';
