import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/videos/data/video_item_detail_dto.dart';
import 'package:sakuramedia/features/videos/data/videos_api.dart';

/// 视频详情控制器：加载 [VideoItemDetailDto]、维护当前选中的媒体源。
///
/// 镜像 `MovieDetailController`，但去掉相似影片/预览图切换等 JAV 专属逻辑。
class VideoDetailController extends ChangeNotifier {
  VideoDetailController({required this.videoId, required this.videosApi});

  final int videoId;
  final VideosApi videosApi;

  VideoItemDetailDto? _detail;
  bool _isLoading = true;
  String? _errorMessage;
  int? _selectedMediaId;

  VideoItemDetailDto? get detail => _detail;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get selectedMediaId => _selectedMediaId;

  MovieMediaItemDto? get selectedMedia {
    final items = _detail?.mediaItems ?? const <MovieMediaItemDto>[];
    for (final item in items) {
      if (item.mediaId == _selectedMediaId) {
        return item;
      }
    }
    return items.isNotEmpty ? items.first : null;
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final detail = await videosApi.getVideoDetail(videoId: videoId);
      _detail = detail;
      _selectedMediaId = _resolveDefaultMediaId(detail);
      _errorMessage = null;
    } catch (error) {
      _detail = null;
      _selectedMediaId = null;
      _errorMessage = _messageForError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  void selectMedia(int mediaId) {
    if (_selectedMediaId == mediaId) {
      return;
    }
    _selectedMediaId = mediaId;
    notifyListeners();
  }

  /// 删除该视频条目及其媒体。成功返回 `true`。
  Future<bool> deleteVideo() async {
    try {
      await videosApi.deleteVideo(videoId);
      return true;
    } catch (_) {
      return false;
    }
  }

  int? _resolveDefaultMediaId(VideoItemDetailDto detail) {
    for (final item in detail.mediaItems) {
      if (item.hasPlayableUrl) {
        return item.mediaId;
      }
    }
    return detail.mediaItems.isNotEmpty ? detail.mediaItems.first.mediaId : null;
  }

  String _messageForError(Object error) {
    if (error is ApiException && error.statusCode == 404) {
      return '未找到该视频';
    }
    return '视频详情暂时无法加载，请稍后重试';
  }
}
