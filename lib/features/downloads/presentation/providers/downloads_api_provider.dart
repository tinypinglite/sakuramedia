import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/configuration/data/api/download_clients_api.dart';
import 'package:sakuramedia/features/downloads/data/downloads_api.dart';

part 'downloads_api_provider.g.dart';

/// downloads feature Riverpod Notifier 读 API 的入口。
///
/// body 抛 [UnimplementedError]，实际实例由 `lib/app/app.dart` 的组合根
/// 用 `overrideWithValue(context.read<DownloadsApi>())` 注入。
@Riverpod(keepAlive: true)
DownloadsApi downloadsApi(Ref ref) {
  throw UnimplementedError('Override downloadsApiProvider at the app root');
}

/// 下载客户端配置 API 的桥接：下载中心需要读客户端列表用于筛选下拉与名称/kind 映射。
///
/// `DownloadClientsApi` 归属 configuration 域；先在 downloads 侧建 bridge，等
/// configuration 迁 Riverpod 时再上移。
@Riverpod(keepAlive: true)
DownloadClientsApi downloadClientsApi(Ref ref) {
  throw UnimplementedError(
    'Override downloadClientsApiProvider at the app root',
  );
}
