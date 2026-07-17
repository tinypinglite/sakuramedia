import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/data/invalid_media_dto.dart';
import 'package:sakuramedia/features/media/data/media_validity_check_result_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/invalid_media_state.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

part 'invalid_media_provider.g.dart';

Duration? noInvalidMediaRetry(int retryCount, Object error) => null;

/// 「媒体维护」失效媒体列表（Riverpod）。
///
/// 复查 → 若已恢复：从列表移除；若仍失效：加入 [InvalidMediaState.deleteEnabledMediaIds]
/// 允许删除。删除 → 移除并扣减 total。单飞守卫：同时只能一项复查/一项删除。
///
/// 迁移前对应：`InvalidMediaController extends PagedLoadController<InvalidMediaDto>`。
@Riverpod(keepAlive: true, retry: noInvalidMediaRetry)
class InvalidMedia extends _$InvalidMedia
    with PagedAsyncNotifierMixin<InvalidMediaState, InvalidMediaDto> {
  @override
  int get pageSize => 20;

  @override
  String get initialLoadErrorText => '失效媒体加载失败，请稍后重试';

  @override
  String get loadMoreErrorText => '加载更多失效媒体失败，请点击重试';

  @override
  PagedListState<InvalidMediaDto> pagedOf(InvalidMediaState s) => s.paged;

  @override
  InvalidMediaState applyPaged(
    InvalidMediaState s,
    PagedListState<InvalidMediaDto> paged,
  ) => s.copyWith(paged: paged);

  @override
  Future<PaginatedResponseDto<InvalidMediaDto>> fetchPage(
    int page,
    int pageSize,
  ) => ref
      .read(mediaApiProvider)
      .getInvalidMedia(page: page, pageSize: pageSize);

  @override
  Future<InvalidMediaState> build() async {
    attachDisposeGuard();
    final paged = await loadInitialPage();
    return InvalidMediaState(paged: paged);
  }

  /// 强制刷新（reload）：额外清空 [InvalidMediaState.deleteEnabledMediaIds]。
  @override
  Future<void> reload({
    InvalidMediaState Function(InvalidMediaState current)? updateBaseState,
  }) {
    return super.reload(
      updateBaseState: (s) {
        final cleared = s.copyWith(
          deleteEnabledMediaIds: const <int>{},
        );
        return updateBaseState != null ? updateBaseState(cleared) : cleared;
      },
    );
  }

  /// 保留态刷新：额外清空 [InvalidMediaState.deleteEnabledMediaIds]。
  @override
  Future<String?> refresh() async {
    final current = state.value;
    if (current != null && current.deleteEnabledMediaIds.isNotEmpty) {
      state = AsyncData(
        current.copyWith(deleteEnabledMediaIds: const <int>{}),
      );
    }
    return super.refresh();
  }

  Future<MediaValidityCheckResultDto> checkValidity({
    required int mediaId,
  }) async {
    final current = state.value;
    if (current == null) {
      throw StateError('media validity check requires loaded state');
    }
    if (current.checkingMediaId != null) {
      throw StateError('media validity check already running');
    }
    state = AsyncData(current.copyWith(checkingMediaId: mediaId));
    try {
      final result = await ref
          .read(mediaApiProvider)
          .checkMediaValidity(mediaId: mediaId);
      if (isDisposed) return result;
      final now = state.value;
      if (now == null) return result;
      if (result.validAfter) {
        state = AsyncData(_withMediaRemoved(now, mediaId));
      } else {
        final nextEnabled = Set<int>.of(now.deleteEnabledMediaIds)..add(mediaId);
        state = AsyncData(
          now.copyWith(
            checkingMediaId: null,
            deleteEnabledMediaIds: nextEnabled,
          ),
        );
      }
      return result;
    } catch (error) {
      if (!isDisposed) {
        final now = state.value;
        if (now != null) {
          state = AsyncData(now.copyWith(checkingMediaId: null));
        }
      }
      rethrow;
    } finally {
      // 若成功路径已经清 checkingMediaId 就没事；异常路径已在 catch 里清。
      // 这里兜底：若仍然是当前 mediaId，清掉。
      final now = state.value;
      if (!isDisposed && now != null && now.checkingMediaId == mediaId) {
        state = AsyncData(now.copyWith(checkingMediaId: null));
      }
    }
  }

  Future<void> deleteInvalidMedia({required int mediaId}) async {
    final current = state.value;
    if (current == null) {
      throw StateError('media deletion requires loaded state');
    }
    if (!current.canDeleteMedia(mediaId)) {
      throw StateError('media deletion requires validity check first');
    }
    if (current.deletingMediaId != null) {
      throw StateError('media deletion already running');
    }
    state = AsyncData(current.copyWith(deletingMediaId: mediaId));
    try {
      await ref.read(mediaApiProvider).deleteMedia(mediaId: mediaId);
      if (isDisposed) return;
      final now = state.value;
      if (now == null) return;
      state = AsyncData(_withMediaRemoved(now, mediaId));
    } catch (error) {
      if (!isDisposed) {
        final now = state.value;
        if (now != null) {
          state = AsyncData(now.copyWith(deletingMediaId: null));
        }
      }
      rethrow;
    } finally {
      final now = state.value;
      if (!isDisposed && now != null && now.deletingMediaId == mediaId) {
        state = AsyncData(now.copyWith(deletingMediaId: null));
      }
    }
  }

  /// 从 items 移除 [mediaId]，同步扣减 total 与 deleteEnabled/checking/deleting 相关字段。
  InvalidMediaState _withMediaRemoved(
    InvalidMediaState current,
    int mediaId,
  ) {
    final beforeLength = current.paged.items.length;
    final nextItems = current.paged.items
        .where((item) => item.id != mediaId)
        .toList(growable: false);
    final removed = beforeLength - nextItems.length;
    final nextTotal = removed > 0 && current.paged.total > 0
        ? (current.paged.total - removed).clamp(0, 1 << 30).toInt()
        : current.paged.total;
    final nextPaged = current.paged.copyWith(
      items: List<InvalidMediaDto>.unmodifiable(nextItems),
      total: nextTotal,
      hasMore: nextItems.length < nextTotal,
    );
    final nextEnabled = Set<int>.of(current.deleteEnabledMediaIds)..remove(mediaId);
    return current.copyWith(
      paged: nextPaged,
      deleteEnabledMediaIds: nextEnabled,
      checkingMediaId: current.checkingMediaId == mediaId
          ? null
          : current.checkingMediaId,
      deletingMediaId: current.deletingMediaId == mediaId
          ? null
          : current.deletingMediaId,
    );
  }
}
