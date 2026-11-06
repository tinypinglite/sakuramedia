import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'indexer_settings_provider.g.dart';

/// 索引器设置的共享远端快照与桌面草稿。
///
/// 下载器列表由 [downloadClientsProvider] 独立提供，避免下载器更新时重建并丢弃
/// 尚未保存的索引器草稿。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class IndexerSettings extends _$IndexerSettings
    with AsyncNotifierDisposeGuardMixin<IndexerSettingsState> {
  @override
  Future<IndexerSettingsState> build() async {
    invalidateOnSignOut(ref);
    attachDisposeGuard();
    final settings = await ref.read(indexerSettingsApiProvider).getSettings();
    return IndexerSettingsState.fromDto(settings);
  }

  Future<void> reload() async {
    state = const AsyncLoading<IndexerSettingsState>();
    final next = await AsyncValue.guard(() async {
      final settings = await ref.read(indexerSettingsApiProvider).getSettings();
      return IndexerSettingsState.fromDto(settings);
    });
    if (!isDisposed) state = next;
  }

  /// 刷新失败时保留当前草稿，避免下拉刷新打断用户正在编辑的内容。
  Future<String?> refresh() async {
    final current = state.value;
    if (current == null) {
      await reload();
      return state.hasError
          ? ref.apiErrorMessage(
              state.error!,
              fallback: ref
                  .read(appLocalizationsProvider)
                  .errorIndexerLoadFailed,
            )
          : null;
    }
    try {
      final settings = await ref.read(indexerSettingsApiProvider).getSettings();
      if (!isDisposed) {
        state = AsyncData(IndexerSettingsState.fromDto(settings));
      }
      return null;
    } catch (error) {
      return ref.apiErrorMessage(
        error,
        fallback: ref.read(appLocalizationsProvider).errorIndexerLoadFailed,
      );
    }
  }

  void updateDraft({List<IndexerEntryDto>? indexers}) {
    final current = state.value;
    if (current == null || current.isSaving) return;
    final draft = IndexerSettingsDto(
      indexers: indexers ?? current.draft.indexers,
    );
    state = AsyncData(current.copyWith(draft: draft));
  }

  Future<IndexerSettingsDto> save() async {
    final current = state.value;
    if (current == null || current.isSaving) {
      return current?.saved ??
          const IndexerSettingsDto(indexers: <IndexerEntryDto>[]);
    }
    state = AsyncData(current.copyWith(isSaving: true));
    try {
      final saved = await ref
          .read(indexerSettingsApiProvider)
          .updateSettings(
            UpdateIndexerSettingsPayload(indexers: current.draft.indexers),
          );
      if (!isDisposed) {
        state = AsyncData(IndexerSettingsState.fromDto(saved));
      }
      return saved;
    } catch (_) {
      if (!isDisposed) state = AsyncData(current.copyWith(isSaving: false));
      rethrow;
    }
  }

  /// 移动端编辑抽屉按原行为立即提交完整 settings，再回写 saved/draft。
  Future<IndexerSettingsDto> saveDraft({
    required List<IndexerEntryDto> indexers,
  }) async {
    updateDraft(indexers: indexers);
    return save();
  }
}
