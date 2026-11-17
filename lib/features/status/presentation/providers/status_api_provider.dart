import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';

part 'status_api_provider.g.dart';

/// status 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。
@Riverpod(keepAlive: true)
StatusApi statusApi(Ref ref) {
  return StatusApi(apiClient: ref.watch(apiClientProvider));
}
