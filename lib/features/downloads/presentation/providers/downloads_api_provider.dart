import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/configuration/data/api/download_clients_api.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';

part 'downloads_api_provider.g.dart';

/// downloads feature Riverpod Notifier 读 API 的入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。
@Riverpod(keepAlive: true)
DownloadsApi downloadsApi(Ref ref) {
  return DownloadsApi(apiClient: ref.watch(apiClientProvider));
}

/// 下载客户端配置 API 的桥接：下载中心需要读客户端列表用于筛选下拉与名称/kind 映射。
///
/// `DownloadClientsApi` 归属 configuration 域；先在 downloads 侧建 bridge，等
/// configuration 迁 Riverpod 时再上移。
@Riverpod(keepAlive: true)
DownloadClientsApi downloadClientsApi(Ref ref) {
  return DownloadClientsApi(apiClient: ref.watch(apiClientProvider));
}
