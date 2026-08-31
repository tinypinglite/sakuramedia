import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/media_import/data/subtitle_import_api.dart';

part 'subtitle_import_api_provider.g.dart';

/// 字幕导入 API 的 Riverpod 入口。
@Riverpod(keepAlive: true)
SubtitleImportApi subtitleImportApi(Ref ref) {
  return SubtitleImportApi(apiClient: ref.watch(apiClientProvider));
}
