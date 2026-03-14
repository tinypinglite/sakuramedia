import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/playlists/data/playlist_dto.dart';

class PlaylistDetailController extends ChangeNotifier {
  PlaylistDetailController({
    required this.playlistId,
    required this.fetchPlaylistDetail,
  });

  final int playlistId;
  final Future<PlaylistDto> Function({required int playlistId})
  fetchPlaylistDetail;

  PlaylistDto? _playlist;
  bool _isLoading = true;
  String? _errorMessage;

  PlaylistDto? get playlist => _playlist;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _playlist = await fetchPlaylistDetail(playlistId: playlistId);
      _errorMessage = null;
    } catch (error) {
      _playlist = null;
      _errorMessage = _messageForError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _messageForError(Object error) {
    if (error is ApiException &&
        (error.statusCode == 404 ||
            error.error?.code == 'playlist_not_found')) {
      return '未找到该播放列表';
    }
    return '播放列表详情暂时无法加载，请稍后重试';
  }
}
