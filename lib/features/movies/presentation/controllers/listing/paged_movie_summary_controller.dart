import 'package:flutter/material.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/shared/presentation/paged_load_controller.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_subscribable_list_mixin.dart';

/// 订阅相关的类型（结果/typedef/mixin）都在 `movie_subscribable_list_mixin.dart`，
/// 这里 re-export，让既有 `import 'paged_movie_summary_controller.dart'` 的调用方
/// 无需改动即可继续拿到 [MovieSubscriptionToggleResult] 等类型。
export 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_subscribable_list_mixin.dart';

typedef MovieSummaryPageFetcher =
    Future<PaginatedResponseDto<MovieListItemDto>> Function(
      int page,
      int pageSize,
    );

class PagedMovieSummaryController extends PagedLoadController<MovieListItemDto>
    with MovieSubscribableListMixin<MovieListItemDto> {
  PagedMovieSummaryController({
    required MovieSummaryPageFetcher fetchPage,
    required this.subscribeMovie,
    required this.unsubscribeMovie,
    this.batchSubscribeMovies = unwiredMovieBatchSubscription,
    this.batchUnsubscribeMovies = unwiredMovieBatchSubscription,
    this.onSubscriptionChanged,
    this.onSubscriptionsBatchChanged,
    int initialPage = 1,
    int pageSize = 24,
    double loadMoreTriggerOffset = 300,
    String initialLoadErrorText = '最新入库影片加载失败，请稍后重试',
    String loadMoreErrorText = '加载更多失败，请点击重试',
    ScrollController? scrollController,
  }) : super(
         fetchPage: fetchPage,
         initialPage: initialPage,
         pageSize: pageSize,
         loadMoreTriggerOffset: loadMoreTriggerOffset,
         initialLoadErrorText: initialLoadErrorText,
         loadMoreErrorText: loadMoreErrorText,
         scrollController: scrollController,
       );

  @override
  final MovieSubscriptionWriter subscribeMovie;
  @override
  final MovieUnsubscriptionWriter unsubscribeMovie;
  @override
  final MovieBatchSubscriptionWriter batchSubscribeMovies;
  @override
  final MovieBatchSubscriptionWriter batchUnsubscribeMovies;
  @override
  final MovieSubscriptionChangeReporter? onSubscriptionChanged;
  @override
  final MovieSubscriptionBatchReporter? onSubscriptionsBatchChanged;

  @override
  String movieNumberOf(MovieListItemDto item) => item.movieNumber;

  @override
  bool isSubscribedOf(MovieListItemDto item) => item.isSubscribed;

  @override
  MovieListItemDto copyWithSubscribed(
    MovieListItemDto item,
    bool isSubscribed,
  ) {
    return item.copyWith(isSubscribed: isSubscribed);
  }
}
