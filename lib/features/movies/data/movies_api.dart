import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_sse_event.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_review_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_search_stream_update.dart';
import 'package:sakuramedia/features/movies/data/parsed_movie_number_dto.dart';
import 'package:sakuramedia/features/search/data/catalog_search_stream_stats.dart';
import 'package:sakuramedia/features/movies/presentation/movie_filter_state.dart';

class MoviesApi {
  const MoviesApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PaginatedResponseDto<MovieListItemDto>> getMovies({
    MovieStatusFilter? status,
    MovieCollectionTypeFilter? collectionType,
    String? sort,
    int? actorId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (status != null) {
      queryParameters['status'] = status.apiValue;
    }
    if (collectionType != null) {
      queryParameters['collection_type'] = collectionType.apiValue;
    }
    if (sort != null && sort.isNotEmpty) {
      queryParameters['sort'] = sort;
    }
    if (actorId != null) {
      queryParameters['actor_id'] = actorId;
    }

    final response = await _apiClient.get(
      '/movies',
      queryParameters: queryParameters,
    );
    return PaginatedResponseDto<MovieListItemDto>.fromJson(
      response,
      MovieListItemDto.fromJson,
    );
  }

  Future<PaginatedResponseDto<MovieListItemDto>> getLatestMovies({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/movies/latest',
      queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    return PaginatedResponseDto<MovieListItemDto>.fromJson(
      response,
      MovieListItemDto.fromJson,
    );
  }

  Future<PaginatedResponseDto<MovieListItemDto>>
  getSubscribedActorsLatestMovies({int page = 1, int pageSize = 20}) async {
    final response = await _apiClient.get(
      '/movies/subscribed-actors/latest',
      queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
    );
    return PaginatedResponseDto<MovieListItemDto>.fromJson(
      response,
      MovieListItemDto.fromJson,
    );
  }

  Future<MovieDetailDto> getMovieDetail({required String movieNumber}) async {
    final response = await _apiClient.get('/movies/$movieNumber');
    return MovieDetailDto.fromJson(response);
  }

  Future<List<MovieReviewDto>> getMovieReviews({
    required String movieNumber,
    int page = 1,
    int pageSize = 20,
    MovieReviewSort sort = MovieReviewSort.recently,
  }) async {
    final response = await _apiClient.getList(
      '/movies/$movieNumber/reviews',
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'sort': sort.apiValue,
      },
    );
    return response.map(MovieReviewDto.fromJson).toList(growable: false);
  }

  Future<List<MovieMediaThumbnailDto>> getMediaThumbnails({
    required int mediaId,
  }) async {
    final response = await _apiClient.getList('/media/$mediaId/thumbnails');
    return response
        .map(MovieMediaThumbnailDto.fromJson)
        .toList(growable: false);
  }

  Future<MovieMediaProgressDto> updateMediaProgress({
    required int mediaId,
    required int positionSeconds,
  }) async {
    final response = await _apiClient.put(
      '/media/$mediaId/progress',
      data: <String, dynamic>{'position_seconds': positionSeconds},
    );
    return MovieMediaProgressDto.fromJson(response);
  }

  Future<ParsedMovieNumberDto> parseMovieNumber({required String query}) async {
    final response = await _apiClient.post(
      '/movies/search/parse-number',
      data: <String, dynamic>{'query': query.trim()},
    );
    return ParsedMovieNumberDto.fromJson(response);
  }

  Future<List<MovieListItemDto>> searchLocalMovies({
    required String movieNumber,
  }) async {
    final response = await _apiClient.getList(
      '/movies/search/local',
      queryParameters: <String, dynamic>{'movie_number': movieNumber},
    );
    return response.map(MovieListItemDto.fromJson).toList(growable: false);
  }

  Stream<MovieSearchStreamUpdate> searchOnlineMoviesStream({
    required String movieNumber,
  }) {
    return _apiClient
        .postSse(
          '/movies/search/javdb/stream',
          data: <String, dynamic>{'movie_number': movieNumber},
        )
        .map(_mapMovieSearchStreamEvent);
  }

  Future<void> subscribeMovie({required String movieNumber}) {
    return _apiClient.putNoContent('/movies/$movieNumber/subscription');
  }

  Future<void> unsubscribeMovie({
    required String movieNumber,
    bool deleteMedia = false,
  }) {
    return _apiClient.deleteNoContent(
      '/movies/$movieNumber/subscription',
      queryParameters: <String, dynamic>{'delete_media': deleteMedia},
    );
  }

  MovieSearchStreamUpdate _mapMovieSearchStreamEvent(ApiSseEvent event) {
    final payload = event.jsonData;

    switch (event.event) {
      case 'search_started':
        return const MovieSearchStreamUpdate(
          stage: 'search_started',
          message: '正在从外部数据源搜索影片',
        );
      case 'movie_found':
        return MovieSearchStreamUpdate(
          stage: 'movie_found',
          message: '已从在线源获取候选影片',
          total: payload['total'] as int?,
        );
      case 'upsert_started':
        return MovieSearchStreamUpdate(
          stage: 'upsert_started',
          message: '正在入库在线影片',
          total: payload['total'] as int?,
        );
      case 'upsert_finished':
        return MovieSearchStreamUpdate(
          stage: 'upsert_finished',
          message: '在线影片入库完成',
          stats: CatalogSearchStreamStats.fromLooseJson(payload),
        );
      case 'completed':
        return MovieSearchStreamUpdate(
          stage: 'completed',
          message: '在线搜索已完成',
          results: _parseMovieResults(payload['movies']),
          success: payload['success'] as bool? ?? false,
          reason: payload['reason'] as String?,
          stats:
              payload.containsKey('stats') || payload.containsKey('total')
                  ? CatalogSearchStreamStats.fromLooseJson(payload)
                  : null,
        );
      default:
        return MovieSearchStreamUpdate(
          stage: event.event,
          message: '正在同步在线影片搜索结果',
        );
    }
  }

  List<MovieListItemDto> _parseMovieResults(dynamic value) {
    if (value is! List) {
      return const <MovieListItemDto>[];
    }
    return value
        .whereType<Object?>()
        .map((item) => MovieListItemDto.fromJson(_toMap(item)))
        .toList(growable: false);
  }

  Map<String, dynamic> _toMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic data) => MapEntry(key.toString(), data),
      );
    }
    return const <String, dynamic>{};
  }
}
