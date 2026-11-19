import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';

class PlaylistsApi {
  const PlaylistsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<PlaylistDto>> getPlaylists({bool includeSystem = true}) async {
    final response = await _apiClient.getList(
      '/playlists',
      queryParameters: <String, dynamic>{'include_system': includeSystem},
    );
    return response.map(PlaylistDto.fromJson).toList(growable: false);
  }

  Future<PlaylistDto> createPlaylist({
    required String name,
    String? description,
    String kind = PlaylistKind.custom,
    Map<String, dynamic>? smartFilter,
  }) async {
    final response = await _apiClient.post(
      '/playlists',
      data: <String, dynamic>{
        'name': name.trim(),
        'kind': kind,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (smartFilter != null) 'filter': smartFilter,
      },
    );
    return PlaylistDto.fromJson(response);
  }

  Future<PlaylistDto> getPlaylistDetail({required int playlistId}) async {
    final response = await _apiClient.get('/playlists/$playlistId');
    return PlaylistDto.fromJson(response);
  }

  Future<PlaylistDto> updatePlaylist({
    required int playlistId,
    required UpdatePlaylistPayload payload,
  }) async {
    final response = await _apiClient.patch(
      '/playlists/$playlistId',
      data: payload.toJson(),
    );
    return PlaylistDto.fromJson(response);
  }

  Future<void> deletePlaylist(int playlistId) {
    return _apiClient.deleteNoContent('/playlists/$playlistId');
  }

  Future<PaginatedResponseDto<MovieListItemDto>> getPlaylistMovies({
    required int playlistId,
    int page = 1,
    int pageSize = 20,
    String? sort,
    String? resolution,
    String? watchStatus,
  }) async {
    final response = await _apiClient.get(
      '/playlists/$playlistId/movies',
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        if (sort != null) 'sort': sort,
        if (resolution != null) 'resolution': resolution,
        if (watchStatus != null) 'watch_status': watchStatus,
      },
    );
    return PaginatedResponseDto<MovieListItemDto>.fromJson(
      response,
      MovieListItemDto.fromJson,
    );
  }

  Future<void> addMovieToPlaylist({
    required int playlistId,
    required String movieNumber,
  }) {
    return _apiClient.putNoContent(
      '/playlists/$playlistId/movies/$movieNumber',
    );
  }

  Future<PlaylistMovieBatchAddResultDto> addMoviesToPlaylist({
    required int playlistId,
    required List<String> movieNumbers,
  }) async {
    final response = await _apiClient.post(
      '/playlists/$playlistId/movies',
      data: <String, dynamic>{'movie_numbers': movieNumbers},
    );
    return PlaylistMovieBatchAddResultDto.fromJson(response);
  }

  Future<void> removeMovieFromPlaylist({
    required int playlistId,
    required String movieNumber,
  }) {
    return _apiClient.deleteNoContent(
      '/playlists/$playlistId/movies/$movieNumber',
    );
  }
}
