import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranked_movie_list_item_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_board_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_source_dto.dart';

class RankingsApi {
  const RankingsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<RankingSourceDto>> getRankingSources() async {
    final response = await _apiClient.getList('/ranking-sources');
    return response.map(RankingSourceDto.fromJson).toList(growable: false);
  }

  Future<List<RankingBoardDto>> getRankingBoards({
    required String sourceKey,
  }) async {
    final response = await _apiClient.getList(
      '/ranking-sources/$sourceKey/boards',
    );
    return response.map(RankingBoardDto.fromJson).toList(growable: false);
  }

  Future<PaginatedResponseDto<RankedMovieListItemDto>> getRankingItems({
    required String sourceKey,
    required String boardKey,
    required String period,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/ranking-sources/$sourceKey/boards/$boardKey/items',
      queryParameters: <String, dynamic>{
        'period': period,
        'page': page,
        'page_size': pageSize,
      },
    );
    return PaginatedResponseDto<RankedMovieListItemDto>.fromJson(
      response,
      RankedMovieListItemDto.fromJson,
    );
  }
}
