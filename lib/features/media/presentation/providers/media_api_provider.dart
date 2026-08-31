import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';

part 'media_api_provider.g.dart';

/// media feature 内所有 Riverpod Notifier 读 API 的统一入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。
@Riverpod(keepAlive: true)
MediaApi mediaApi(Ref ref) {
  return MediaApi(apiClient: ref.watch(apiClientProvider));
}

/// media 页需要读媒体库列表（用于筛选、秒传目标选择、存储描述解析）。
///
/// `MediaLibrariesApi` 归属 configuration 域；configuration 迁移完成后该
/// bridge 仍保持现状（configuration 页面、media、system_diagnostics、
/// media_import 选择器等多处共用，原生装配无副作用）。
@Riverpod(keepAlive: true)
MediaLibrariesApi mediaLibrariesApi(Ref ref) {
  return MediaLibrariesApi(apiClient: ref.watch(apiClientProvider));
}
