import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/image_search/data/image_search_api.dart';

part 'image_search_api_provider.g.dart';

/// image_search 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。
@Riverpod(keepAlive: true)
ImageSearchApi imageSearchApi(Ref ref) {
  return ImageSearchApi(apiClient: ref.watch(apiClientProvider));
}
