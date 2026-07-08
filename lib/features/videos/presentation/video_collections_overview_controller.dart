import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/api/video_collections_api.dart';

/// 视频合集列表控制器（合集列表为非分页 `List`）。
class VideoCollectionsOverviewController extends ChangeNotifier {
  VideoCollectionsOverviewController({required this.collectionsApi});

  final VideoCollectionsApi collectionsApi;

  List<VideoCollectionDto> _collections = const <VideoCollectionDto>[];
  bool _isLoading = true;
  String? _errorMessage;

  List<VideoCollectionDto> get collections => _collections;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _collections = await collectionsApi.getCollections();
      _errorMessage = null;
    } catch (error) {
      _errorMessage = apiErrorMessage(error, fallback: '合集加载失败，请稍后重试');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();
}
