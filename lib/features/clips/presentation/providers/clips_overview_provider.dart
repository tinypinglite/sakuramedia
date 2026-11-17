import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_api_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_filter.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_overview_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

part 'clips_overview_provider.g.dart';

/// 我的切片首页分页列表（排序筛选驱动）。
///
/// 切排序时先更新控件并保留旧列表，防抖拉取的新结果成功后再原子替换。
///
/// autoDispose：离开页面即释放，对齐迁移前控制器随 State 生灭。
///
/// 迁移前对应：`ClipsOverviewController`（含 `_clips` / `_page` / `_total` 手写字段、
/// `removeClip` / `replaceClip` 广播补丁方法）。
@Riverpod(retry: kNoAsyncNotifierRetry)
class ClipsOverview extends _$ClipsOverview
    with
        PagedAsyncNotifierMixin<ClipsOverviewState, MediaClipDto>,
        FilterablePagedAsyncNotifierMixin<
          ClipsOverviewState,
          MediaClipDto,
          ClipsFilter
        > {
  @override
  int get pageSize => 24;

  @override
  String get initialLoadErrorText =>
      ref.read(appLocalizationsProvider).errorClipLoadFailed;

  @override
  String get loadMoreErrorText =>
      ref.read(appLocalizationsProvider).errorLoadMoreRetry;

  @override
  ClipsFilter get initialFilter => const ClipsFilter();

  @override
  PagedListState<MediaClipDto> pagedOf(ClipsOverviewState s) => s.paged;

  @override
  ClipsOverviewState applyPaged(
    ClipsOverviewState s,
    PagedListState<MediaClipDto> paged,
  ) => s.copyWith(paged: paged);

  @override
  ClipsOverviewState applyFilterToState(
    ClipsOverviewState s,
    ClipsFilter filter,
  ) => s.copyWith(filter: filter);

  @override
  Future<PaginatedResponseDto<MediaClipDto>> fetchPage(
    int page,
    int pageSize,
  ) => ref
      .read(clipsApiProvider)
      .getMyClips(page: page, pageSize: pageSize, sort: activeFilter.sort);

  @override
  Future<ClipsOverviewState> build() async {
    attachDisposeGuard();
    final paged = await loadInitialPage();
    return ClipsOverviewState(paged: paged, filter: activeFilter);
  }

  /// 顶栏按钮切排序：值对象 `==` 短路，避免同值触发无谓请求。
  Future<void> applySort(String sort) =>
      applyFilterState(activeFilter.copyWith(sort: sort));

  /// ClipMutation 广播补丁：从已加载列表中就地移除（同步扣 total / 重算 hasMore）。
  void removeClip(int clipId) {
    final current = state.value;
    if (current == null) return;
    final next = current.paged.removeWhere((c) => c.clipId == clipId);
    if (identical(next, current.paged)) return;
    state = AsyncData(current.copyWith(paged: next));
  }

  /// 重命名成功后就地替换（不动 total / hasMore）。
  void replaceClip(MediaClipDto clip) {
    final current = state.value;
    if (current == null) return;
    final next = current.paged.patchWhere(
      (c) => c.clipId == clip.clipId,
      (_) => clip,
    );
    if (identical(next, current.paged)) return;
    state = AsyncData(current.copyWith(paged: next));
  }
}
