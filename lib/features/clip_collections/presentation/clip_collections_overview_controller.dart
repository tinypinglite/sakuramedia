import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collection_dto.dart';

typedef ClipCollectionsFetcher = Future<List<ClipCollectionDto>> Function();

/// 切片合集列表控制器：合集集合不分页（后端 `/clip-collections` 一次性返回）。
class ClipCollectionsOverviewController extends ChangeNotifier {
  ClipCollectionsOverviewController({required this.fetchCollections});

  final ClipCollectionsFetcher fetchCollections;

  List<ClipCollectionDto> _collections = const <ClipCollectionDto>[];
  bool _isLoading = true;
  String? _errorMessage;

  List<ClipCollectionDto> get collections => _collections;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => !_isLoading && _errorMessage == null && _collections.isEmpty;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _collections = await fetchCollections();
      _errorMessage = null;
    } catch (error) {
      _collections = const <ClipCollectionDto>[];
      _errorMessage = apiErrorMessage(error, fallback: '合集暂时无法加载，请稍后重试');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  /// 新建合集后置顶插入（后端列表按更新时间倒序，新建即最新）。
  void insertCollection(ClipCollectionDto collection) {
    _collections = <ClipCollectionDto>[collection, ..._collections];
    notifyListeners();
  }

  void replaceCollection(ClipCollectionDto collection) {
    final index = _collections.indexWhere((item) => item.id == collection.id);
    if (index < 0) {
      return;
    }
    final updated = List<ClipCollectionDto>.from(_collections);
    updated[index] = collection;
    _collections = updated;
    notifyListeners();
  }

  void removeCollection(int collectionId) {
    final before = _collections.length;
    _collections =
        _collections
            .where((item) => item.id != collectionId)
            .toList(growable: false);
    if (_collections.length != before) {
      notifyListeners();
    }
  }
}
