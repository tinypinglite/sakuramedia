import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_draft_store.dart';

part 'image_search_draft_store_provider.g.dart';

/// 图搜草稿仓 [ImageSearchDraftStore] 的 Riverpod 入口。
///
/// 原生装配：组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。
@Riverpod(keepAlive: true)
ImageSearchDraftStore imageSearchDraftStore(Ref ref) {
  return ImageSearchDraftStore();
}
