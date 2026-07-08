import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/clip_mutation_change_notifier.dart';

/// 影片详情页「切片」区块的数据控制器。
///
/// 按番号拉取该片的全部切片（命中后端 `MediaClip.movie_number` 快照列，来源 Media
/// 删除后仍可查询）。本控制器只持纯数据 + 本地补丁，交互（播放 / 改名 / 删除 / 加入
/// 合集）落在页面侧的 `MovieClipSectionMixin`。删除经 [ClipMutationChangeNotifier]
/// 广播，本控制器监听后就地移除——亦能感知「我的切片」页删除同一切片时的外部变更，
/// 避免详情页停留时列表 stale。
class MovieClipsController extends ChangeNotifier {
  MovieClipsController({
    required this.movieNumber,
    required this.fetchClips,
    required ClipMutationChangeNotifier mutationNotifier,
  }) : _mutationNotifier = mutationNotifier {
    _mutationNotifier.addListener(_onMutation);
  }

  final String movieNumber;
  final Future<List<MediaClipDto>> Function({
    required String movieNumber,
    int limit,
  })
  fetchClips;

  final ClipMutationChangeNotifier _mutationNotifier;

  /// 详情页不做分页，一次性取该片前若干条切片。
  static const int _limit = 30;

  List<MediaClipDto> _clips = const <MediaClipDto>[];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;

  List<MediaClipDto> get clips => _clips;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    // 番号缺失无从过滤，直接落空态（区块在页面侧隐藏）。
    if (movieNumber.trim().isEmpty) {
      _clips = const <MediaClipDto>[];
      _isLoading = false;
      _errorMessage = null;
      _notify();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _notify();

    try {
      final clips = await fetchClips(movieNumber: movieNumber, limit: _limit);
      _clips = clips;
      _errorMessage = null;
    } catch (_) {
      _errorMessage = '切片暂时无法加载，请稍后重试';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> retry() => load();

  /// 重命名后用更新项就地替换同 id 切片（无该 id 则忽略）。
  void replaceClip(MediaClipDto updated) {
    final index = _clips.indexWhere((clip) => clip.clipId == updated.clipId);
    if (index < 0) {
      return;
    }
    final next = List<MediaClipDto>.of(_clips);
    next[index] = updated;
    _clips = List<MediaClipDto>.unmodifiable(next);
    _notify();
  }

  /// 从列表精准移除指定切片（删除广播 / 本地删除共用）。
  void removeClip(int clipId) {
    final before = _clips.length;
    _clips =
        _clips.where((clip) => clip.clipId != clipId).toList(growable: false);
    if (_clips.length != before) {
      _notify();
    }
  }

  void _onMutation() {
    final change = _mutationNotifier.lastChange;
    if (change == null) {
      return;
    }
    if (change.kind == ClipMutationKind.deleted && change.clipId != null) {
      removeClip(change.clipId!);
    }
  }

  void _notify() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _mutationNotifier.removeListener(_onMutation);
    super.dispose();
  }
}
