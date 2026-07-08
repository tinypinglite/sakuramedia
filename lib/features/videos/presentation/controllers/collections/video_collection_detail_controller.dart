import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/api/video_collections_api.dart';
import 'package:sakuramedia/features/videos/data/api/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';

/// 视频合集详情控制器：加载合集与有序成员，支持排序、乐观重排与移除。
///
/// 排序复用全部视频列表的 [VideoSortField] + [SortDirection]，并以 `_sortField == null`
/// 表示「手动顺序」（后端 `position:asc`）。手动顺序下才允许拖拽重排，由页面据
/// [isManualOrder] 决定是否启用 `ReorderableListView`。
class VideoCollectionDetailController extends ChangeNotifier {
  VideoCollectionDetailController({
    required this.collectionId,
    required this.collectionsApi,
    required this.videosApi,
  });

  final int collectionId;
  final VideoCollectionsApi collectionsApi;
  final VideosApi videosApi;

  VideoCollectionDto? _collection;
  List<VideoCollectionItemDto> _items = const <VideoCollectionItemDto>[];
  bool _isLoading = true;
  bool _isMutating = false;
  String? _errorMessage;

  // null = 手动顺序（position:asc），其余复用视频列表排序字段。
  VideoSortField? _sortField;
  SortDirection _sortDirection = SortDirection.asc;

  VideoCollectionDto? get collection => _collection;
  List<VideoCollectionItemDto> get items => _items;
  bool get isLoading => _isLoading;
  bool get isMutating => _isMutating;
  String? get errorMessage => _errorMessage;

  VideoSortField? get sortField => _sortField;
  SortDirection get sortDirection => _sortDirection;

  /// 当前是否为手动顺序：仅此模式下允许拖拽重排。
  bool get isManualOrder => _sortField == null;

  /// 传给后端的排序表达式；手动顺序返回 `null`（后端默认 `position:asc`）。
  ///
  /// 对外公开，供「播放全部」把详情页当前排序沿导航链路透传到连播页，
  /// 使连播列表与详情页列表同序（startIndex 映射随之正确）。
  String? get sortExpression {
    final field = _sortField;
    if (field == null) {
      return null;
    }
    return '${field.apiValue}:${_sortDirection.apiValue}';
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final collection =
          await collectionsApi.getCollection(collectionId: collectionId);
      final items = await collectionsApi.getAllCollectionItems(
        collectionId: collectionId,
        sort: sortExpression,
        // 带上播放地址：成员既供详情列表展示，也可经「交接信箱」直接交给连播页
        // 组装播放列表，省去连播页二次全量拉取。
        includePlayUrl: true,
      );
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

  /// 切换排序：先更新状态并通知（工具条与拖拽开关即时切换），再按新排序重拉成员。
  /// 保留旧 [_items] 直到新数据返回，避免列表闪烁；失败时保留原列表并提示。
  Future<void> applySort({
    required VideoSortField? field,
    SortDirection? direction,
  }) async {
    _sortField = field;
    if (direction != null) {
      _sortDirection = direction;
    }
    _errorMessage = null;
    notifyListeners();
    try {
      final items = await collectionsApi.getAllCollectionItems(
        collectionId: collectionId,
        sort: sortExpression,
        // 带上播放地址：成员既供详情列表展示，也可经「交接信箱」直接交给连播页
        // 组装播放列表，省去连播页二次全量拉取。
        includePlayUrl: true,
      );
      _items = items;
    } catch (error) {
      _errorMessage = apiErrorMessage(error, fallback: '排序失败，请稍后重试');
    } finally {
      notifyListeners();
    }
  }

  /// 乐观重排：先本地移动并通知，再下发 reorder；失败则回滚到原顺序。
  /// 改动在途时（[_isMutating]）忽略并发重排，避免乐观状态相互覆盖。
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (_isMutating) {
      return;
    }
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
    final previous = _items;
    final reordered = List<VideoCollectionItemDto>.of(_items);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(target, moved);
    _items = reordered;
    _isMutating = true;
    notifyListeners();
    try {
      await collectionsApi.reorderCollectionItems(
        collectionId: collectionId,
        orderedItemIds:
            reordered.map((item) => item.itemId).toList(growable: false),
      );
    } catch (_) {
      // 失败回滚到提交前的本地顺序（即服务端真实顺序）。
      _items = previous;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  /// 从合集移除成员（乐观更新）；成功返回 `null`，失败回滚并返回错误消息。
  Future<String?> removeItem(int itemId) async {
    if (_isMutating) {
      return null;
    }
    final previous = _items;
    _items =
        _items.where((item) => item.itemId != itemId).toList(growable: false);
    _isMutating = true;
    notifyListeners();
    try {
      await collectionsApi.removeCollectionItem(
        collectionId: collectionId,
        itemId: itemId,
      );
      return null;
    } catch (error) {
      _items = previous;
      return apiErrorMessage(error, fallback: '移除失败，请重试');
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  /// 彻底删除视频本体（连同文件，不可恢复，乐观更新）；成功返回 `null`，失败回滚并
  /// 返回错误消息。与 [removeItem] 区别：调用 `videosApi.deleteVideo` 删除视频本身，
  /// 而非仅解除合集归属，因此调用方成功后应广播 `reportDeleted`（而非成员变化）。
  Future<String?> deleteVideo(int itemId, int videoId) async {
    if (_isMutating) {
      return null;
    }
    final previous = _items;
    _items =
        _items.where((item) => item.itemId != itemId).toList(growable: false);
    _isMutating = true;
    notifyListeners();
    try {
      await videosApi.deleteVideo(videoId);
      return null;
    } catch (error) {
      _items = previous;
      return apiErrorMessage(error, fallback: '删除失败，请重试');
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }
}
