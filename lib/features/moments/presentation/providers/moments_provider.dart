import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/features/moments/presentation/providers/moments_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

part 'moments_provider.g.dart';

/// 时刻分页列表（排序 + 内容类型双维筛选,值对象 [MomentsFilter] 驱动）。
///
/// - 切筛选先更新条件并保留旧列表，防抖请求成功后再替换结果。
/// - autoDispose:离开页面即释放,对齐迁移前控制器随页面 State 生灭。
/// - `fetchPage` 保留 `MediaPointListItemDto → MomentListItem` 的 ViewModel
///   映射（迁移前在控制器 override 里做）。
///
/// 迁移前对应:`PagedMomentController`。
@Riverpod(retry: kNoAsyncNotifierRetry)
class Moments extends _$Moments
    with
        PagedAsyncNotifierMixin<MomentsState, MomentListItem>,
        FilterablePagedAsyncNotifierMixin<
          MomentsState,
          MomentListItem,
          MomentsFilter
        > {
  @override
  int get pageSize => 20;

  @override
  String get initialLoadErrorText =>
      ref.read(appLocalizationsProvider).errorMomentListLoadFailed;

  @override
  String get loadMoreErrorText =>
      ref.read(appLocalizationsProvider).errorLoadMoreFailed;

  @override
  MomentsFilter get initialFilter => MomentsFilter.initial;

  /// 当前选中筛选；首次加载尚无 state 时供页面渲染默认标签。
  MomentsFilter get filter => activeFilter;

  @override
  PagedListState<MomentListItem> pagedOf(MomentsState s) => s.paged;

  @override
  MomentsState applyPaged(
    MomentsState s,
    PagedListState<MomentListItem> paged,
  ) => s.copyWith(paged: paged);

  @override
  MomentsState applyFilterToState(MomentsState s, MomentsFilter filter) =>
      s.copyWith(filter: filter);

  @override
  Future<PaginatedResponseDto<MomentListItem>> fetchPage(
    int page,
    int pageSize,
  ) async {
    final response = await ref
        .read(mediaApiProvider)
        .getGlobalMediaPoints(
          page: page,
          pageSize: pageSize,
          sort: activeFilter.sortOrder.apiValue,
          kind: activeFilter.kindFilter.apiValue,
        );
    return PaginatedResponseDto<MomentListItem>(
      items: response.items
          .map(
            (item) => MomentListItem(
              pointId: item.pointId,
              mediaId: item.mediaId,
              movieNumber: item.movieNumber,
              videoItemId: item.videoItemId,
              thumbnailId: item.thumbnailId,
              offsetSeconds: item.offsetSeconds,
              image: item.image,
            ),
          )
          .toList(growable: false),
      page: response.page,
      pageSize: response.pageSize,
      total: response.total,
    );
  }

  @override
  Future<MomentsState> build() async {
    attachDisposeGuard();
    final paged = await loadInitialPage();
    return MomentsState(paged: paged, filter: activeFilter);
  }
}
