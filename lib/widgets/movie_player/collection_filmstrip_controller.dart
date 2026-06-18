import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';

/// 某集（按「实际可播列表」下标）的原始关键帧：`offsetSeconds` 是**该集自身播放时间轴**
/// 的相对秒数（切片相对切片起点、pornbox 相对媒体起点，两者都对应「该集从 0 起播」）。
/// 切片缩略图 / 媒体缩略图两种数据源归一成此形状后喂入控制器。
///
/// `mediaId` / `thumbnailId` 供右面板「添加时刻」用（创建 MediaPoint 需二者）：pornbox 帧
/// 来自媒体缩略图，填真实 id；切片帧无对应 media（时刻基于 media），填 `0` 即不支持时刻。
typedef CollectionEpisodeFrames =
    List<({int offsetSeconds, MovieImageDto image, int mediaId, int thumbnailId})>;

/// 取某集关键帧的注入闭包；失败或无帧时返回空（控制器静默跳过该集帧段）。
typedef CollectionEpisodeFrameLoader =
    Future<CollectionEpisodeFrames> Function(int episodeIndex);

/// 全局帧：归属集下标 + 集内相对秒数 + 图片。按 `(episodeIndex, offset)` 顺序排列。
@immutable
class CollectionFrame {
  const CollectionFrame({
    required this.episodeIndex,
    required this.offsetInEpisodeSeconds,
    required this.image,
    required this.mediaId,
    required this.thumbnailId,
  });

  final int episodeIndex;
  final int offsetInEpisodeSeconds;
  final MovieImageDto image;

  /// 帧所属媒体与缩略图 id（供「添加时刻」创建 MediaPoint）；切片帧均为 `0`（不支持时刻）。
  final int mediaId;
  final int thumbnailId;
}

/// 把整个合集的关键帧聚合成「一部完整长片」的全局缩略图序列：按集顺序无缝拼接第 1…N 集
/// 的全部关键帧，对外暴露成现成缩略图网格要的 [MovieMediaThumbnailDto] 列表，并维护
/// 「当前播放位置 → 全局活动帧」与「点击全局帧 → 所属集 + 集内秒数」两个方向的映射。
///
/// **渐进式加载**：按集下标升序逐集拉取并**追加**（append-only，不回插，避免已显示的帧
/// 重排抖动）；首集帧到达即 `isLoading→false` 开始显示，单集失败/空帧只跳过该段、不阻断
/// 播放。喂给纯展示网格，故 `thumbnailId/mediaId` 填 0 占位（网格只消费 image/高亮/点击）。
class CollectionFilmstripController extends ChangeNotifier {
  CollectionFilmstripController({
    required int episodeCount,
    required CollectionEpisodeFrameLoader frameLoader,
  }) : _episodeCount = math.max(0, episodeCount),
       _frameLoader = frameLoader {
    _episodeFrames = List<List<CollectionFrame>?>.filled(
      _episodeCount,
      null,
      growable: false,
    );
    _episodeStartIndex = List<int>.filled(_episodeCount, 0, growable: false);
  }

  final int _episodeCount;
  final CollectionEpisodeFrameLoader _frameLoader;

  /// 每集帧桶；`null` = 尚未加载完成，加载完成（含失败/空）后为不可空列表。
  late final List<List<CollectionFrame>?> _episodeFrames;

  /// 每集在全局序列里的起始 index，随帧桶填充重算。
  late List<int> _episodeStartIndex;

  List<CollectionFrame> _frames = const <CollectionFrame>[];

  /// [thumbnails] 的惰性缓存：仅由 `_frames` 派生，`_rebuild` 时置 null 失效，下次读取
  /// getter 再构建一次。避免每次进度 tick（面板因 [activeIndex] 变化重建）都全量重算。
  List<MovieMediaThumbnailDto>? _thumbnailsCache;
  int _attemptedCount = 0;
  bool _started = false;
  bool _isDisposed = false;

  int? _currentEpisode;
  int _currentPositionSeconds = 0;

  /// 当前播放位置对应的全局帧下标；与 [thumbnails] 同坐标系，喂网格高亮 / 滚动跟随。
  /// 用 [ValueNotifier] 单独广播，避免每次进度 tick 都重建整个面板。
  final ValueNotifier<int?> activeIndex = ValueNotifier<int?>(null);

  // 网格列数 / 滚动锁状态，语义对齐 jav 播放器缩略图面板。
  int? _columns;
  bool _usesAutoColumns = true;
  bool _isScrollLocked = true;

  /// 惰性构建并缓存：从 `_frames` 投影成网格要的 DTO。`mediaId/thumbnailId` 透传帧的真实
  /// id（pornbox 真值、切片为 0）——网格用 index 定位、不依赖 id 渲染，但「添加时刻」据此创建
  /// MediaPoint。`offsetSeconds` 为集内相对秒（仅供网格内部展示，跨集 seek 走 `resolveTarget`）。
  List<MovieMediaThumbnailDto> get thumbnails =>
      _thumbnailsCache ??= _frames
          .map(
            (frame) => MovieMediaThumbnailDto(
              thumbnailId: frame.thumbnailId,
              mediaId: frame.mediaId,
              offsetSeconds: frame.offsetInEpisodeSeconds,
              image: frame.image,
            ),
          )
          .toList(growable: false);
  int get episodeCount => _episodeCount;
  int get loadedEpisodeCount => _attemptedCount;

  /// 首集帧到达前显示骨架；全部集已尝试仍无帧时转空态（由网格四态处理）。
  bool get isLoading => _frames.isEmpty && _attemptedCount < _episodeCount;

  int? get columns => _columns;
  bool get usesAutoColumns => _usesAutoColumns;
  bool get isScrollLocked => _isScrollLocked;

  /// 启动渐进加载（仅一次）。优先拉 [priorityEpisode]（实际起播集），其帧最先到达、
  /// 当前集高亮立即可用；其余集再按下标升序补齐。全局序列始终按集下标排列（`_rebuild`
  /// 与加载顺序解耦），故起播集先到时其帧落在中段、随更早集补齐而向后挪——为「中途
  /// 起播也能马上看到当前集帧」接受这点重排（自动滚动跟随活动帧，视觉影响有限）。
  Future<void> start({int priorityEpisode = 0}) async {
    if (_started || _isDisposed || _episodeCount == 0) {
      return;
    }
    _started = true;
    final order = <int>[
      if (priorityEpisode >= 0 && priorityEpisode < _episodeCount)
        priorityEpisode,
      for (var ep = 0; ep < _episodeCount; ep++)
        if (ep != priorityEpisode) ep,
    ];
    for (final ep in order) {
      if (_isDisposed) {
        return;
      }
      await _loadEpisode(ep);
    }
  }

  Future<void> _loadEpisode(int episodeIndex) async {
    CollectionEpisodeFrames raw;
    try {
      raw = await _frameLoader(episodeIndex);
    } catch (_) {
      // 单集失败静默跳过：该集帧段为空，不影响其它集与播放。
      raw = const <({
        int offsetSeconds,
        MovieImageDto image,
        int mediaId,
        int thumbnailId,
      })>[];
    }
    if (_isDisposed) {
      return;
    }
    final frames =
        raw
            .map(
              (frame) => CollectionFrame(
                episodeIndex: episodeIndex,
                offsetInEpisodeSeconds: frame.offsetSeconds,
                image: frame.image,
                mediaId: frame.mediaId,
                thumbnailId: frame.thumbnailId,
              ),
            )
            .toList(growable: false)
          ..sort(
            (a, b) =>
                a.offsetInEpisodeSeconds.compareTo(b.offsetInEpisodeSeconds),
          );
    _episodeFrames[episodeIndex] = frames;
    _attemptedCount++;
    _rebuild();
    _notifySafely();
  }

  void _rebuild() {
    final flat = <CollectionFrame>[];
    for (var ep = 0; ep < _episodeCount; ep++) {
      _episodeStartIndex[ep] = flat.length;
      final bucket = _episodeFrames[ep];
      if (bucket != null) {
        flat.addAll(bucket);
      }
    }
    _frames = flat;
    _thumbnailsCache = null; // 失效，下次读 thumbnails getter 再惰性构建。
    _recomputeActive();
  }

  /// 播放推进时由页面驱动：[episodeIndex] 为「实际可播列表」下标，[positionSeconds]
  /// 为该集内播放秒数。在该集帧段内取 `offset <= position` 的最后一帧作为活动帧。
  void updatePosition(int episodeIndex, int positionSeconds) {
    if (_isDisposed) {
      return;
    }
    _currentEpisode = episodeIndex;
    _currentPositionSeconds = positionSeconds;
    _recomputeActive();
  }

  void _recomputeActive() {
    final ep = _currentEpisode;
    if (ep == null || ep < 0 || ep >= _episodeCount) {
      activeIndex.value = null;
      return;
    }
    final bucket = _episodeFrames[ep];
    if (bucket == null || bucket.isEmpty) {
      activeIndex.value = null;
      return;
    }
    // 取 offset<=position 的最后一帧；播放位置早于首帧 offset 时无满足项→不高亮。
    int? local;
    for (var i = 0; i < bucket.length; i++) {
      if (bucket[i].offsetInEpisodeSeconds <= _currentPositionSeconds) {
        local = i;
      } else {
        break;
      }
    }
    activeIndex.value = local == null ? null : _episodeStartIndex[ep] + local;
  }

  /// 点击全局帧时还原其归属集与集内秒数，供页面做（必要时跨集的）跳转。
  ({int episodeIndex, int offsetSeconds})? resolveTarget(int globalIndex) {
    if (globalIndex < 0 || globalIndex >= _frames.length) {
      return null;
    }
    final frame = _frames[globalIndex];
    return (
      episodeIndex: frame.episodeIndex,
      offsetSeconds: frame.offsetInEpisodeSeconds,
    );
  }

  void applyAutoColumns(int columns) {
    if (!_usesAutoColumns || _columns == columns || _isDisposed) {
      return;
    }
    _columns = columns;
    _notifySafely();
  }

  void setColumns(int columns) {
    if (_isDisposed) {
      return;
    }
    _usesAutoColumns = false;
    _columns = columns;
    _notifySafely();
  }

  void toggleScrollLock() {
    if (_isDisposed) {
      return;
    }
    _isScrollLocked = !_isScrollLocked;
    _notifySafely();
  }

  void _notifySafely() {
    if (_isDisposed) {
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    activeIndex.dispose();
    super.dispose();
  }
}
