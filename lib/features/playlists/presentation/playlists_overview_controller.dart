import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/playlists/data/playlist_dto.dart';

typedef PlaylistListFetcher =
    Future<List<PlaylistDto>> Function({bool includeSystem});
typedef PlaylistCoverFetcher = Future<String?> Function(int playlistId);
typedef PlaylistCreator =
    Future<PlaylistDto> Function({required String name, String? description});

class PlaylistsOverviewController extends ChangeNotifier {
  PlaylistsOverviewController({
    required this.fetchPlaylists,
    required this.fetchPlaylistCoverUrl,
    required this.createPlaylist,
  });

  final PlaylistListFetcher fetchPlaylists;
  final PlaylistCoverFetcher fetchPlaylistCoverUrl;
  final PlaylistCreator createPlaylist;

  List<PlaylistDto> _playlists = const <PlaylistDto>[];
  final Map<int, String?> _coverUrls = <int, String?>{};
  bool _isLoading = true;
  bool _isCreating = false;
  String? _errorMessage;

  List<PlaylistDto> get playlists => _playlists;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String? get errorMessage => _errorMessage;

  String? coverUrlFor(int playlistId) => _coverUrls[playlistId];

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final playlists = await fetchPlaylists(includeSystem: true);
      _playlists = playlists;
      _errorMessage = null;
      notifyListeners();
      await _loadCoverUrls(playlists);
    } catch (error) {
      _playlists = const <PlaylistDto>[];
      _errorMessage = apiErrorMessage(error, fallback: '播放列表暂时无法加载，请稍后重试');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PlaylistDto> createNewPlaylist({
    required String name,
    String? description,
  }) async {
    _isCreating = true;
    notifyListeners();
    try {
      final playlist = await createPlaylist(
        name: name,
        description: description,
      );
      _playlists = <PlaylistDto>[playlist, ..._playlists];
      _coverUrls[playlist.id] = null;
      notifyListeners();
      return playlist;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  void insertPlaylist(PlaylistDto playlist) {
    _playlists = <PlaylistDto>[playlist, ..._playlists];
    _coverUrls[playlist.id] = null;
    notifyListeners();
  }

  Future<void> _loadCoverUrls(List<PlaylistDto> playlists) async {
    for (final playlist in playlists) {
      if (playlist.movieCount <= 0) {
        _coverUrls[playlist.id] = null;
        continue;
      }
      try {
        _coverUrls[playlist.id] = await fetchPlaylistCoverUrl(playlist.id);
      } catch (_) {
        _coverUrls[playlist.id] = null;
      }
      notifyListeners();
    }
  }
}
