import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';

typedef ClipPageFetcher =
    Future<PaginatedResponseDto<MediaClipDto>> Function({
      int page,
      int pageSize,
      String sort,
    });

class ClipsOverviewController extends ChangeNotifier {
  ClipsOverviewController({
    required this.fetchClips,
    this.pageSize = 24,
    String initialSort = 'created_at:desc',
  }) : _sort = initialSort;

  final ClipPageFetcher fetchClips;
  final int pageSize;

  String _sort;
  String get sort => _sort;

  List<MediaClipDto> _clips = const <MediaClipDto>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  int _total = 0;
  String? _errorMessage;
  String? _loadMoreErrorMessage;

  List<MediaClipDto> get clips => _clips;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  String? get loadMoreErrorMessage => _loadMoreErrorMessage;
  bool get hasMore => _clips.length < _total;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    _loadMoreErrorMessage = null;
    notifyListeners();

    try {
      final result = await fetchClips(page: 1, pageSize: pageSize, sort: _sort);
      _clips = result.items;
      _page = result.page;
      _total = result.total;
      _errorMessage = null;
    } catch (error) {
      _clips = const <MediaClipDto>[];
      _errorMessage = apiErrorMessage(error, fallback: '切片暂时无法加载，请稍后重试');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();

  /// 切换排序并从首页重新加载；排序未变化时不触发请求。
  Future<void> setSort(String sort) {
    if (_sort == sort) {
      return Future<void>.value();
    }
    _sort = sort;
    return load();
  }

  /// 加载下一页并追加；失败时保留原列表并记录错误供页面提供重试。
  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !hasMore) {
      return;
    }
    _isLoadingMore = true;
    _loadMoreErrorMessage = null;
    notifyListeners();

    try {
      final result = await fetchClips(
        page: _page + 1,
        pageSize: pageSize,
        sort: _sort,
      );
      _clips = <MediaClipDto>[..._clips, ...result.items];
      _page = result.page;
      _total = result.total;
    } catch (error) {
      _loadMoreErrorMessage = apiErrorMessage(error, fallback: '加载更多失败，请重试');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  void removeClip(int clipId) {
    final before = _clips.length;
    _clips = _clips
        .where((clip) => clip.clipId != clipId)
        .toList(growable: false);
    if (_clips.length != before) {
      _total = (_total - (before - _clips.length)).clamp(0, 1 << 31);
      notifyListeners();
    }
  }

  void replaceClip(MediaClipDto clip) {
    final updated = List<MediaClipDto>.from(_clips);
    final index = updated.indexWhere((item) => item.clipId == clip.clipId);
    if (index < 0) {
      return;
    }
    updated[index] = clip;
    _clips = updated;
    notifyListeners();
  }
}
