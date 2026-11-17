import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/clip_collections/data/api/clip_collections_api.dart';

part 'clip_collections_api_provider.g.dart';

/// clip_collections 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。
@Riverpod(keepAlive: true)
ClipCollectionsApi clipCollectionsApi(Ref ref) {
  return ClipCollectionsApi(apiClient: ref.watch(apiClientProvider));
}
