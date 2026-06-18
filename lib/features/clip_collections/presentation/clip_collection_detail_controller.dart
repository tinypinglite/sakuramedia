import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/data/clip_collections_api.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';

/// 合集详情控制器：加载合集元信息 + 全量有序切片，支持拖序与移除。
///
/// 合集切片量通常不大，这里一次性把所有分页拉全，便于本地重排后用
/// `setCollectionClips` 提交完整有序列表（后端按列表重新编号 position）。
class ClipCollectionDetailController extends ChangeNotifier {
  ClipCollectionDetailController({
    required this.collectionId,
    required this.api,
    this.pageSize = 50,
  });

  final int collectionId;
  final ClipCollectionsApi api;
  final int pageSize;

  ClipCollectionDto? _collection;
  List<MediaClipDto> _clips = const <MediaClipDto>[];
  bool _isLoading = true;
  bool _isMutating = false;
  String? _errorMessage;

  ClipCollectionDto? get collection => _collection;
  List<MediaClipDto> get clips => _clips;
  bool get isLoading => _isLoading;
  bool get isMutating => _isMutating;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => !_isLoading && _errorMessage == null && _clips.isEmpty;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final detail = await api.getCollectionDetail(collectionId: collectionId);
      final clips = await api.getAllCollectionClips(
        collectionId: collectionId,
        pageSize: pageSize,
      );
      _collection = detail;
      _clips = clips;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = apiErrorMessage(error, fallback: '合集详情暂时无法加载，请稍后重试');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  /// 本地重排并提交完整有序列表；失败时回滚并返回错误消息。
  Future<String?> reorder(int oldIndex, int newIndex) async {
    if (_isMutating) {
      return null;
    }
    final previous = _clips;
    final updated = List<MediaClipDto>.from(_clips);
    var targetIndex = newIndex;
    if (targetIndex > oldIndex) {
      targetIndex -= 1;
    }
    final moved = updated.removeAt(oldIndex);
    updated.insert(targetIndex, moved);

    _clips = updated;
    _isMutating = true;
    notifyListeners();
    try {
      await api.setCollectionClips(
        collectionId: collectionId,
        clipIds: updated.map((clip) => clip.clipId).toList(growable: false),
      );
      return null;
    } catch (error) {
      _clips = previous;
      return apiErrorMessage(error, fallback: '排序失败，请重试');
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  /// 从合集移除切片（乐观更新）；失败时回滚并返回错误消息。
  Future<String?> removeClip(int clipId) async {
    if (_isMutating) {
      return null;
    }
    final previous = _clips;
    _clips =
        _clips.where((clip) => clip.clipId != clipId).toList(growable: false);
    _isMutating = true;
    notifyListeners();
    try {
      await api.removeClipFromCollection(
        collectionId: collectionId,
        clipId: clipId,
      );
      _syncCount();
      return null;
    } catch (error) {
      _clips = previous;
      return apiErrorMessage(error, fallback: '移除失败，请重试');
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  /// 编辑合集名称 / 描述后就地更新头部元信息（不重拉切片列表）。
  void applyCollectionMeta(ClipCollectionDto collection) {
    _collection = ClipCollectionDto(
      id: collection.id,
      name: collection.name,
      description: collection.description,
      // 片段数仍以当前列表为准，避免编辑响应与本地状态不一致。
      clipCount: _clips.length,
      coverImage: _collection?.coverImage ?? collection.coverImage,
      createdAt: collection.createdAt,
      updatedAt: collection.updatedAt,
    );
    notifyListeners();
  }

  void _syncCount() {
    final current = _collection;
    if (current != null) {
      _collection = ClipCollectionDto(
        id: current.id,
        name: current.name,
        description: current.description,
        clipCount: _clips.length,
        coverImage: current.coverImage,
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
      );
    }
  }
}
