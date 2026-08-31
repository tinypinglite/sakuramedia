import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_list_item_dto.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_period.dart';

class HotReviewsApi {
  const HotReviewsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PaginatedResponseDto<HotReviewListItemDto>> getHotReviews({
    HotReviewPeriod period = HotReviewPeriod.weekly,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/hot-reviews',
      queryParameters: <String, dynamic>{
        'period': period.apiValue,
        'page': page,
        'page_size': pageSize,
      },
    );
    return PaginatedResponseDto<HotReviewListItemDto>.fromJson(
      response,
      HotReviewListItemDto.fromJson,
    );
  }
}
