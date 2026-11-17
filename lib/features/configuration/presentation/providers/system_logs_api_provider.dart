import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/configuration/data/api/system_logs_api.dart';

part 'system_logs_api_provider.g.dart';

@Riverpod(keepAlive: true)
SystemLogsApi systemLogsApi(Ref ref) {
  return SystemLogsApi(apiClient: ref.watch(apiClientProvider));
}
