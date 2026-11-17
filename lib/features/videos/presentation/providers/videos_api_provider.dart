import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/videos/data/api/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/api/videos_api.dart';

part 'videos_api_provider.g.dart';

/// videos 域三个 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。
@Riverpod(keepAlive: true)
VideosApi videosApi(Ref ref) {
  return VideosApi(apiClient: ref.watch(apiClientProvider));
}

@Riverpod(keepAlive: true)
VideoCollectionsApi videoCollectionsApi(Ref ref) {
  return VideoCollectionsApi(apiClient: ref.watch(apiClientProvider));
}
