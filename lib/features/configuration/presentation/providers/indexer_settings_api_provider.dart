import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/configuration/data/api/indexer_settings_api.dart';

part 'indexer_settings_api_provider.g.dart';

/// configuration 域 IndexerSettingsApi 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。
@Riverpod(keepAlive: true)
IndexerSettingsApi indexerSettingsApi(Ref ref) {
  return IndexerSettingsApi(apiClient: ref.watch(apiClientProvider));
}
