import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/playlists/data/playlist_dto.dart';

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
  }) async {
    final response = await _apiClient.post(
      '/playlists',
      data: <String, dynamic>{
        'name': name.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    return PlaylistDto.fromJson(response);
  }

  Future<PlaylistDto> getPlaylistDetail({required int playlistId}) async {
    final response = await _apiClient.get('/playlists/$playlistId');
    return PlaylistDto.fromJson(response);
  }

  Future<PaginatedResponseDto<MovieListItemDto>> getPlaylistMovies({
    required int playlistId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/playlists/$playlistId/movies',
      queryParameters: <String, dynamic>{'page': page, 'page_size': pageSize},
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

  Future<void> removeMovieFromPlaylist({
    required int playlistId,
    required String movieNumber,
  }) {
    return _apiClient.deleteNoContent(
      '/playlists/$playlistId/movies/$movieNumber',
    );
  }
}
