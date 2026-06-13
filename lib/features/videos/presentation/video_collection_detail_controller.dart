import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/video_collections_api.dart';

/// 视频合集详情控制器：加载合集与有序成员，支持乐观重排与移除。
class VideoCollectionDetailController extends ChangeNotifier {
  VideoCollectionDetailController({
    required this.collectionId,
    required this.collectionsApi,
  });

  final int collectionId;
  final VideoCollectionsApi collectionsApi;

  VideoCollectionDto? _collection;
  List<VideoCollectionItemDto> _items = const <VideoCollectionItemDto>[];
  bool _isLoading = true;
  String? _errorMessage;

  VideoCollectionDto? get collection => _collection;
  List<VideoCollectionItemDto> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// 当前成员对应的有序视频 id 列表，供连播上下文使用。
  List<int> get orderedVideoIds =>
      _items.map((item) => item.video.id).toList(growable: false);

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final collection =
          await collectionsApi.getCollection(collectionId: collectionId);
      final items =
          await collectionsApi.getCollectionItems(collectionId: collectionId);
      _collection = collection;
      _items = items;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = apiErrorMessage(error, fallback: '合集加载失败，请稍后重试');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  /// 乐观重排：先本地移动并通知，再下发 reorder；失败则重载回滚到服务端顺序。
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _items.length) {
      return;
    }
    var target = newIndex;
    if (target > oldIndex) {
      target -= 1;
    }
    if (target < 0) {
      target = 0;
    }
    if (target >= _items.length) {
      target = _items.length - 1;
    }
    if (target == oldIndex) {
      return;
    }
    final reordered = List<VideoCollectionItemDto>.of(_items);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(target, moved);
    _items = reordered;
    notifyListeners();
    try {
      await collectionsApi.reorderCollectionItems(
        collectionId: collectionId,
        orderedItemIds:
            reordered.map((item) => item.itemId).toList(growable: false),
      );
    } catch (_) {
      // 失败回滚到服务端真实顺序。
      await load();
    }
  }

  /// 从合集移除成员，成功返回 `true`。
  Future<bool> removeItem(int itemId) async {
    try {
      await collectionsApi.removeCollectionItem(
        collectionId: collectionId,
        itemId: itemId,
      );
      _items = _items
          .where((item) => item.itemId != itemId)
          .toList(growable: false);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
