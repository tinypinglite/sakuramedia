import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/discovery/data/daily_recommendation_movie_dto.dart';
import 'package:sakuramedia/features/discovery/data/hot_actress_release_movie_dto.dart';
import 'package:sakuramedia/features/discovery/data/moment_recommendation_dto.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_api_provider.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/hot_actress_release_subscription_changes.dart';
import 'package:sakuramedia/features/movies/presentation/providers/mutation_events_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

part 'discovery_recommendation_feeds_provider.g.dart';

/// 「发现 → 全部推荐影片」分页列表(桌面/移动共用页面,family 参数为每页条数:
/// 桌面 24 / 移动 18)。
///
/// autoDispose:离开页面即释放,与迁移前「裸 `PagedLoadController` 随页面
/// State 生灭」的语义等价;本页无跨导航保活需求。
@Riverpod(retry: kNoAsyncNotifierRetry)
class DailyRecommendationFeed extends _$DailyRecommendationFeed
    with
        PagedAsyncNotifierMixin<
          PagedListState<DailyRecommendationMovieDto>,
          DailyRecommendationMovieDto
        > {
  @override
  int get pageSize => itemsPerPage;

  @override
  String get initialLoadErrorText => '推荐影片加载失败，请稍后重试';

  @override
  String get loadMoreErrorText => '加载更多推荐影片失败，请点击重试';

  @override
  PagedListState<DailyRecommendationMovieDto> pagedOf(
    PagedListState<DailyRecommendationMovieDto> s,
  ) => s;

  @override
  PagedListState<DailyRecommendationMovieDto> applyPaged(
    PagedListState<DailyRecommendationMovieDto> s,
    PagedListState<DailyRecommendationMovieDto> paged,
  ) => paged;

  @override
  Future<PaginatedResponseDto<DailyRecommendationMovieDto>> fetchPage(
    int page,
    int pageSize,
  ) => ref
      .read(discoveryApiProvider)
      .getDailyRecommendations(page: page, pageSize: pageSize);

  @override
  Future<PagedListState<DailyRecommendationMovieDto>> build(
    int itemsPerPage,
  ) async {
    attachDisposeGuard();
    return loadInitialPage();
  }
}

@Riverpod(retry: kNoAsyncNotifierRetry)
class HotActressReleaseFeed extends _$HotActressReleaseFeed
    with
        PagedAsyncNotifierMixin<
          PagedListState<HotActressReleaseMovieDto>,
          HotActressReleaseMovieDto
        > {
  @override
  int get pageSize => itemsPerPage;

  @override
  String get initialLoadErrorText => '热门新片加载失败，请稍后重试';

  @override
  String get loadMoreErrorText => '加载更多热门新片失败，请点击重试';

  @override
  PagedListState<HotActressReleaseMovieDto> pagedOf(
    PagedListState<HotActressReleaseMovieDto> state,
  ) => state;

  @override
  PagedListState<HotActressReleaseMovieDto> applyPaged(
    PagedListState<HotActressReleaseMovieDto> state,
    PagedListState<HotActressReleaseMovieDto> paged,
  ) => paged;

  @override
  Future<PaginatedResponseDto<HotActressReleaseMovieDto>> fetchPage(
    int page,
    int pageSize,
  ) => ref
      .read(discoveryApiProvider)
      .getHotActressReleases(page: page, pageSize: pageSize);

  @override
  Future<PagedListState<HotActressReleaseMovieDto>> build(
    int itemsPerPage,
  ) async {
    attachDisposeGuard();
    ref.listen(movieSubscriptionEventsProvider, (_, next) {
      final current = state.value;
      final changes = next.value;
      if (current == null || changes == null) return;
      final items = current.items.withSubscriptionChanges(changes);
      if (!identical(items, current.items)) {
        state = AsyncData(current.copyWith(items: items));
      }
    });
    return loadInitialPage();
  }
}

/// 「发现 → 全部推荐时刻」分页列表,同上(family 参数为每页条数)。
///
/// `MomentRecommendationPageDto` 不是 `PaginatedResponseDto` 子类(多携带
/// `generatedAt`),这里做一次类型适配;适配只此一处,页面不再各自复制。
@Riverpod(retry: kNoAsyncNotifierRetry)
class MomentRecommendationFeed extends _$MomentRecommendationFeed
    with
        PagedAsyncNotifierMixin<
          PagedListState<MomentRecommendationDto>,
          MomentRecommendationDto
        > {
  @override
  int get pageSize => itemsPerPage;

  @override
  String get initialLoadErrorText => '推荐时刻加载失败，请稍后重试';

  @override
  String get loadMoreErrorText => '加载更多推荐时刻失败，请点击重试';

  @override
  PagedListState<MomentRecommendationDto> pagedOf(
    PagedListState<MomentRecommendationDto> s,
  ) => s;

  @override
  PagedListState<MomentRecommendationDto> applyPaged(
    PagedListState<MomentRecommendationDto> s,
    PagedListState<MomentRecommendationDto> paged,
  ) => paged;

  @override
  Future<PaginatedResponseDto<MomentRecommendationDto>> fetchPage(
    int page,
    int pageSize,
  ) async {
    final response = await ref
        .read(discoveryApiProvider)
        .getMomentRecommendations(page: page, pageSize: pageSize);
    return PaginatedResponseDto<MomentRecommendationDto>(
      items: response.items,
      page: response.page,
      pageSize: response.pageSize,
      total: response.total,
    );
  }

  @override
  Future<PagedListState<MomentRecommendationDto>> build(
    int itemsPerPage,
  ) async {
    attachDisposeGuard();
    return loadInitialPage();
  }
}
