import 'package:flutter/material.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_list_item_dto.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_period.dart';
import 'package:sakuramedia/features/shared/presentation/paged_load_controller.dart';

typedef HotReviewPageFetcher =
    Future<PaginatedResponseDto<HotReviewListItemDto>> Function(
      int page,
      int pageSize,
      HotReviewPeriod period,
    );

class PagedHotReviewController
    extends PagedLoadController<HotReviewListItemDto> {
  PagedHotReviewController({
    required HotReviewPageFetcher fetchPage,
    int initialPage = 1,
    int pageSize = 20,
    double loadMoreTriggerOffset = 300,
    String initialLoadErrorText = '热评加载失败，请稍后重试',
    String loadMoreErrorText = '加载更多失败，请点击重试',
    ScrollController? scrollController,
  }) : _fetchPage = fetchPage,
       super(
         fetchPage:
             (_, __) =>
                 throw UnimplementedError(
                   'PagedHotReviewController overrides fetchPage.',
                 ),
         initialPage: initialPage,
         pageSize: pageSize,
         loadMoreTriggerOffset: loadMoreTriggerOffset,
         initialLoadErrorText: initialLoadErrorText,
         loadMoreErrorText: loadMoreErrorText,
         scrollController: scrollController,
       );

  final HotReviewPageFetcher _fetchPage;
  HotReviewPeriod _period = HotReviewPeriod.weekly;
  HotReviewPeriod get period => _period;

  @override
  Future<PaginatedResponseDto<HotReviewListItemDto>> fetchPage(
    int page,
    int pageSize,
  ) {
    return _fetchPage(page, pageSize, _period);
  }

  Future<void> setPeriod(HotReviewPeriod nextPeriod) async {
    if (_period == nextPeriod) {
      return;
    }
    _period = nextPeriod;
    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
    await reload();
  }
}
