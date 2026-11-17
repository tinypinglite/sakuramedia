import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/recent_views/data/api/recent_views_api.dart';

part 'recent_views_api_provider.g.dart';

/// recent_views 域 API 的 Riverpod 入口。
@Riverpod(keepAlive: true)
RecentViewsApi recentViewsApi(Ref ref) {
  return RecentViewsApi(apiClient: ref.watch(apiClientProvider));
}
