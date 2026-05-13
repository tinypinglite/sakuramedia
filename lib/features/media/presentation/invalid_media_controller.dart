import 'package:sakuramedia/features/media/data/invalid_media_dto.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';
import 'package:sakuramedia/features/media/data/media_validity_check_result_dto.dart';
import 'package:sakuramedia/features/shared/presentation/paged_load_controller.dart';

class InvalidMediaController extends PagedLoadController<InvalidMediaDto> {
  InvalidMediaController({
    required MediaApi mediaApi,
    super.initialPage = 1,
    super.pageSize = 20,
    super.loadMoreTriggerOffset = 300,
    super.scrollController,
  }) : _mediaApi = mediaApi,
       super(
         fetchPage:
             (page, pageSize) =>
                 mediaApi.getInvalidMedia(page: page, pageSize: pageSize),
         initialLoadErrorText: '失效媒体加载失败，请稍后重试',
         loadMoreErrorText: '加载更多失效媒体失败，请点击重试',
       );

  final MediaApi _mediaApi;
  final Set<int> _deleteEnabledMediaIds = <int>{};

  int? _checkingMediaId;
  int? _deletingMediaId;

  int? get checkingMediaId => _checkingMediaId;
  int? get deletingMediaId => _deletingMediaId;

  bool canDeleteMedia(int mediaId) => _deleteEnabledMediaIds.contains(mediaId);

  @override
  Future<void> initialize() {
    _deleteEnabledMediaIds.clear();
    return super.initialize();
  }

  @override
  Future<void> reload() {
    _deleteEnabledMediaIds.clear();
    return super.reload();
  }

  @override
  Future<void> refresh() {
    _deleteEnabledMediaIds.clear();
    return super.refresh();
  }

  Future<MediaValidityCheckResultDto> checkValidity({
    required int mediaId,
  }) async {
    if (_checkingMediaId != null) {
      throw StateError('media validity check already running');
    }
    _checkingMediaId = mediaId;
    notifyListenersSafely();

    try {
      final result = await _mediaApi.checkMediaValidity(mediaId: mediaId);
      if (result.validAfter) {
        _removeMedia(mediaId);
      } else {
        _deleteEnabledMediaIds.add(mediaId);
      }
      return result;
    } finally {
      _checkingMediaId = null;
      notifyListenersSafely();
    }
  }

  Future<void> deleteInvalidMedia({required int mediaId}) async {
    if (!canDeleteMedia(mediaId)) {
      throw StateError('media deletion requires validity check first');
    }
    if (_deletingMediaId != null) {
      throw StateError('media deletion already running');
    }
    _deletingMediaId = mediaId;
    notifyListenersSafely();

    try {
      await _mediaApi.deleteMedia(mediaId: mediaId);
      _removeMedia(mediaId);
    } finally {
      _deletingMediaId = null;
      notifyListenersSafely();
    }
  }

  void _removeMedia(int mediaId) {
    _deleteEnabledMediaIds.remove(mediaId);
    final beforeLength = mutableItems.length;
    mutableItems.removeWhere((item) => item.id == mediaId);
    if (mutableItems.length != beforeLength && mutableTotal > 0) {
      mutableTotal = mutableTotal - 1;
    }
  }
}
