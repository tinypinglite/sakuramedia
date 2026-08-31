import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_reviews_api.dart';

part 'hot_reviews_api_provider.g.dart';

/// hot_reviews 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。
@Riverpod(keepAlive: true)
HotReviewsApi hotReviewsApi(Ref ref) {
  return HotReviewsApi(apiClient: ref.watch(apiClientProvider));
}
