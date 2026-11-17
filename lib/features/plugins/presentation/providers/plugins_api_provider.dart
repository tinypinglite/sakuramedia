import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/plugins/data/plugins_api.dart';

part 'plugins_api_provider.g.dart';

/// plugins 域 [PluginsApi] 的 Riverpod 入口。
@Riverpod(keepAlive: true)
PluginsApi pluginsApi(Ref ref) {
  return PluginsApi(apiClient: ref.watch(apiClientProvider));
}
