import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/subscriptions/data/api/movie_subscriptions_api.dart';

part 'movie_subscriptions_api_provider.g.dart';

/// 订阅管理 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。
@Riverpod(keepAlive: true)
MovieSubscriptionsApi movieSubscriptionsApi(Ref ref) {
  return MovieSubscriptionsApi(apiClient: ref.watch(apiClientProvider));
}
