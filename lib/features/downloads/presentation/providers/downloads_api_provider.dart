import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/configuration/data/api/download_clients_api.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';

part 'downloads_api_provider.g.dart';

/// downloads feature 读取 API 的入口。
@Riverpod(keepAlive: true)
DownloadsApi downloadsApi(Ref ref) {
  return DownloadsApi(apiClient: ref.watch(apiClientProvider));
}

/// 下载客户端配置 API 的桥接：下载中心需要客户端列表用于筛选下拉与名称映射。
@Riverpod(keepAlive: true)
DownloadClientsApi downloadClientsApi(Ref ref) {
  return DownloadClientsApi(apiClient: ref.watch(apiClientProvider));
}
