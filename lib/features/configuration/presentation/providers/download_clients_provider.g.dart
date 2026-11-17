// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_clients_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 跨桌面 configuration tab 与移动设置页共享的下载器列表。

@ProviderFor(DownloadClients)
final downloadClientsProvider = DownloadClientsProvider._();

/// 跨桌面 configuration tab 与移动设置页共享的下载器列表。
final class DownloadClientsProvider
    extends $AsyncNotifierProvider<DownloadClients, List<DownloadClientDto>> {
  /// 跨桌面 configuration tab 与移动设置页共享的下载器列表。
  DownloadClientsProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'downloadClientsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$downloadClientsHash();

  @$internal
  @override
  DownloadClients create() => DownloadClients();
}

String _$downloadClientsHash() => r'bca4126f76b1f6fc62c23065a9371b10b13f76dc';

/// 跨桌面 configuration tab 与移动设置页共享的下载器列表。

abstract class _$DownloadClients
    extends $AsyncNotifier<List<DownloadClientDto>> {
  FutureOr<List<DownloadClientDto>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<DownloadClientDto>>,
              List<DownloadClientDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<DownloadClientDto>>,
                List<DownloadClientDto>
              >,
              AsyncValue<List<DownloadClientDto>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
