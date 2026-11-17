import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';
import 'package:sakuramedia/features/status/data/server_capabilities.dart';
import 'package:sakuramedia/features/status/presentation/providers/status_api_provider.dart';

part 'server_capabilities_provider.g.dart';

@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
Future<ServerCapabilities> serverCapabilities(Ref ref) async {
  invalidateOnSessionChange(ref);
  final session = ref.watch(sessionStoreProvider);
  if (!session.hasSession) {
    return const ServerCapabilities(imageSearch: false, movieSimilarity: false);
  }
  try {
    return await ref.watch(statusApiProvider).getCapabilities();
  } on ApiException catch (error) {
    // 旧后端没有此接口，沿用其全部能力；网络错误不能被解释为已启用。
    if (error.statusCode == 404) return const ServerCapabilities();
    rethrow;
  }
}

@riverpod
bool imageSearchEnabled(Ref ref) =>
    ref.watch(serverCapabilitiesProvider).value?.imageSearch ?? false;

@riverpod
bool movieSimilarityEnabled(Ref ref) =>
    ref.watch(serverCapabilitiesProvider).value?.movieSimilarity ?? false;
