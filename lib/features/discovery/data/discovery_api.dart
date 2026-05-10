import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/discovery/data/daily_recommendation_movie_dto.dart';
import 'package:sakuramedia/features/discovery/data/moment_recommendation_dto.dart';

class DiscoveryApi {
  const DiscoveryApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PaginatedResponseDto<DailyRecommendationMovieDto>>
  getDailyRecommendations({int page = 1, int pageSize = 20}) async {
    final response = await _apiClient.get(
      '/daily-recommendations',
      queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    return PaginatedResponseDto<DailyRecommendationMovieDto>.fromJson(
      response,
      DailyRecommendationMovieDto.fromJson,
    );
  }

  Future<MomentRecommendationPageDto> getMomentRecommendations({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/moment-recommendations',
      queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    return MomentRecommendationPageDto.fromJson(response);
  }
}
