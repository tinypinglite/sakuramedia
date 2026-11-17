import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/media_import/data/media_import_api.dart';

part 'media_import_api_provider.g.dart';

/// media_import 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。
@Riverpod(keepAlive: true)
MediaImportApi mediaImportApi(Ref ref) {
  return MediaImportApi(apiClient: ref.watch(apiClientProvider));
}
