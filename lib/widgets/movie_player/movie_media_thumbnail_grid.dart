import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/app_image_action_trigger.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

/// 缩略图网格的两种布局：
/// - [uniform16x9]：所有 tile 统一 16:9，竖图运行时回退 `BoxFit.contain` 两侧留底（历史行为）。
/// - [staggered]：按帧自带 `width`/`height` 排版的瀑布流，pornbox 合集连播页使用——同集内
///   tile 等高、集与集之间自然错落，混合横竖图无两侧留底。
enum ThumbnailGridLayout { uniform16x9, staggered }

/// pornbox 关键帧多为竖图；宽高比 < 此阈值时用 contain 完整展示，否则 cover 填满 tile。
/// 仅 [ThumbnailGridLayout.uniform16x9] 分支使用——瀑布流分支预先按真实比例切 tile，cover 即可。
const double _kAdaptiveFitAspectThreshold = 1.5;

/// 瀑布流缺 width/height 时按 16:9 占位（与 uniform 分支历史行为对齐）。
const double _kStaggeredFallbackAspect = 16 / 9;

/// 按图片真实宽高比（宽/高）选填充方式：竖/方图（< 1.5）用 contain 完整展示，
/// 横图（>= 1.5）用 cover 填满。测得前（null）或无效（<=0）回退 cover，等同原行为、不闪烁。
@visibleForTesting
BoxFit resolveAdaptiveThumbnailFit(double? aspectRatio) {
  if (aspectRatio == null || aspectRatio <= 0) {
    return BoxFit.cover;
  }
  return aspectRatio < _kAdaptiveFitAspectThreshold
      ? BoxFit.contain
      : BoxFit.cover;
}

/// 瀑布流单个 tile 的归位结果：所在列 + 顶端 y 偏移 + tile 高度。
@immutable
class StaggeredTilePlacement {
  const StaggeredTilePlacement({
    required this.columnIndex,
    required this.topOffset,
    required this.height,
  });

  final int columnIndex;
  final double topOffset;
  final double height;

  double get bottomOffset => topOffset + height;
}

/// 瀑布流整组布局结果：每 tile 的归位 + 各列累计高度 + 单 tile 宽度。
@immutable
class StaggeredLayoutResult {
  const StaggeredLayoutResult({
    required this.tiles,
    required this.columnHeights,
    required this.tileWidth,
  });

  final List<StaggeredTilePlacement> tiles;
  final List<double> columnHeights;
  final double tileWidth;

  /// 整组瀑布流总高 = 最长列高（不含尾部 mainAxisSpacing）。
  double get totalHeight =>
      columnHeights.isEmpty
          ? 0
          : columnHeights.reduce((a, b) => a > b ? a : b);
}

/// 计算瀑布流 tile 归位：**镜像** `SliverMasonryGrid.count` 的「当前最矮列优先」放置算法
/// （并列时取最左列），同集内 tile 等高会自然形成整齐行；缺 w/h 的 tile 回退 16:9。
///
/// 暴露成纯函数供面板内部预算可视范围 / 自动滚动目标偏移用——只要算法与库一致，前端预算
/// 的 `topOffset` 就等同库实际渲染位置；库换实现的小风险由 layout 单测覆盖。
@visibleForTesting
StaggeredLayoutResult computeStaggeredLayout({
  required int crossAxisCount,
  required double availableWidth,
  required double crossAxisSpacing,
  required double mainAxisSpacing,
  required List<({int? width, int? height})> items,
  double fallbackAspect = _kStaggeredFallbackAspect,
}) {
  final safeColumns = math.max(0, crossAxisCount);
  if (safeColumns == 0 || items.isEmpty || availableWidth <= 0) {
    return StaggeredLayoutResult(
      tiles: const <StaggeredTilePlacement>[],
      columnHeights: List<double>.filled(safeColumns, 0, growable: false),
      tileWidth: 0,
    );
  }
  final tileWidth =
      (availableWidth - crossAxisSpacing * (safeColumns - 1)) / safeColumns;
  if (tileWidth <= 0) {
    return StaggeredLayoutResult(
      tiles: const <StaggeredTilePlacement>[],
      columnHeights: List<double>.filled(safeColumns, 0, growable: false),
      tileWidth: 0,
    );
  }
  final columnHeights = List<double>.filled(safeColumns, 0, growable: false);
  final tiles = <StaggeredTilePlacement>[];
  for (final item in items) {
    final w = item.width;
    final h = item.height;
    final aspect =
        (w != null && h != null && w > 0 && h > 0) ? w / h : fallbackAspect;
    final tileHeight = tileWidth / aspect;
    var bestColumn = 0;
    for (var c = 1; c < safeColumns; c++) {
      if (columnHeights[c] < columnHeights[bestColumn]) {
        bestColumn = c;
      }
    }
    final top = columnHeights[bestColumn];
    tiles.add(
      StaggeredTilePlacement(
        columnIndex: bestColumn,
        topOffset: top,
        height: tileHeight,
      ),
    );
    columnHeights[bestColumn] = top + tileHeight + mainAxisSpacing;
  }
  // 去掉尾部多记的 mainAxisSpacing，让 totalHeight 等于最后一行 tile 的底端。
  for (var c = 0; c < safeColumns; c++) {
    if (columnHeights[c] > 0) {
      columnHeights[c] -= mainAxisSpacing;
    }
  }
  return StaggeredLayoutResult(
    tiles: List<StaggeredTilePlacement>.unmodifiable(tiles),
    columnHeights: columnHeights,
    tileWidth: tileWidth,
  );
}

class MovieMediaThumbnailGrid extends StatefulWidget {
  const MovieMediaThumbnailGrid({
    super.key,
    required this.thumbnails,
    required this.isLoading,
    required this.errorMessage,
    required this.columns,
    required this.activeIndex,
    required this.isScrollLocked,
    required this.onThumbnailTap,
    required this.onRetry,
    this.onThumbnailMenuRequested,
    this.clipStartIndex,
    this.clipEndIndex,
    this.keyPrefix = 'movie-media',
    this.layout = ThumbnailGridLayout.uniform16x9,
  });

  final List<MovieMediaThumbnailDto> thumbnails;
  final bool isLoading;
  final String? errorMessage;
  final int columns;
  final int? activeIndex;
  final bool isScrollLocked;
  final int? clipStartIndex;
  final int? clipEndIndex;
  final ValueChanged<int> onThumbnailTap;
  final VoidCallback onRetry;
  final void Function(int index, Offset globalPosition)?
  onThumbnailMenuRequested;
  final String keyPrefix;

  /// 网格布局：默认走历史的统一 16:9；pornbox 合集连播页传 [ThumbnailGridLayout.staggered]
  /// 走瀑布流，按帧自带 w/h 排版。
  final ThumbnailGridLayout layout;

  @override
  State<MovieMediaThumbnailGrid> createState() =>
      _MovieMediaThumbnailGridState();
}

class _MovieMediaThumbnailGridState extends State<MovieMediaThumbnailGrid> {
  static const Duration _scrollIdleDuration = Duration(milliseconds: 100);
  static const Duration _autoScrollThrottleDuration = Duration(
    milliseconds: 180,
  );
  static const int _visibleRowBuffer = 2;
  static const double _decodeDevicePixelRatioCap = 2.0;
  static const int _decodeSizeUpperBound = 1024;

  late final ScrollController _scrollController;
  Timer? _scrollIdleTimer;
  Timer? _autoScrollThrottleTimer;
  bool _isUserScrollInProgress = false;
  bool _hasPendingAutoScroll = false;
  bool _hasPendingVisibleRangeRefresh = false;
  Size? _lastGridLayoutSize;
  int? _visibleStartIndex;
  int? _visibleEndIndex;
  final Set<int> _renderedImageIndices = <int>{};

  /// 瀑布流分支：每 tile 归位（按当前 grid 宽 + 列数 + thumbnails 算出），随 layout 变化重算。
  StaggeredLayoutResult? _staggeredLayout;

  /// 算出 [_staggeredLayout] 时的 grid 宽度；宽度变化（分栏拖动 / 窗口缩放）即令缓存失效。
  double? _staggeredLayoutWidth;

  /// 瀑布流分支可视范围（不连续，故用 Set；uniform 分支继续走 start/end 双指针）。
  final Set<int> _staggeredVisibleIndices = <int>{};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _markScrollSettled();
    });
    if (widget.isScrollLocked) {
      _scheduleScrollToActive(immediate: true);
    }
  }

  @override
  void dispose() {
    _scrollIdleTimer?.cancel();
    _autoScrollThrottleTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MovieMediaThumbnailGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRenderedImageCache(oldWidget);
    final shouldAutoScroll =
        widget.isScrollLocked && _shouldAutoScroll(oldWidget);
    if (oldWidget.thumbnails.length != widget.thumbnails.length ||
        oldWidget.columns != widget.columns ||
        oldWidget.layout != widget.layout) {
      // 瀑布流缓存的 layout 依赖 thumbnails/columns/layout 模式，任一变就失效重算。
      _staggeredLayout = null;
      _staggeredLayoutWidth = null;
      _scheduleVisibleRangeRefreshAfterLayout();
    }
    if (oldWidget.isScrollLocked && !widget.isScrollLocked) {
      _cancelAutoScrollThrottle();
    }
    if (shouldAutoScroll) {
      _scheduleScrollToActive(immediate: _shouldScrollImmediately(oldWidget));
    }
  }

  bool _shouldAutoScroll(MovieMediaThumbnailGrid oldWidget) {
    return oldWidget.activeIndex != widget.activeIndex ||
        oldWidget.columns != widget.columns ||
        oldWidget.isScrollLocked != widget.isScrollLocked ||
        oldWidget.thumbnails.length != widget.thumbnails.length;
  }

  bool _shouldScrollImmediately(MovieMediaThumbnailGrid oldWidget) {
    return !oldWidget.isScrollLocked && widget.isScrollLocked ||
        oldWidget.columns != widget.columns ||
        oldWidget.thumbnails.length != widget.thumbnails.length;
  }

  void _syncRenderedImageCache(MovieMediaThumbnailGrid oldWidget) {
    if (widget.thumbnails.isEmpty) {
      _renderedImageIndices.clear();
      return;
    }

    if (_didThumbnailDatasetChange(oldWidget)) {
      _renderedImageIndices.clear();
      return;
    }

    _renderedImageIndices.removeWhere(
      (index) => index >= widget.thumbnails.length,
    );
  }

  bool _didThumbnailDatasetChange(MovieMediaThumbnailGrid oldWidget) {
    final oldThumbnails = oldWidget.thumbnails;
    final nextThumbnails = widget.thumbnails;
    if (oldThumbnails.length != nextThumbnails.length) {
      return true;
    }

    for (var index = 0; index < nextThumbnails.length; index++) {
      final oldThumbnail = oldThumbnails[index];
      final nextThumbnail = nextThumbnails[index];
      if (oldThumbnail.thumbnailId != nextThumbnail.thumbnailId ||
          oldThumbnail.mediaId != nextThumbnail.mediaId ||
          oldThumbnail.offsetSeconds != nextThumbnail.offsetSeconds ||
          oldThumbnail.image.bestAvailableUrl !=
              nextThumbnail.image.bestAvailableUrl ||
          oldThumbnail.width != nextThumbnail.width ||
          oldThumbnail.height != nextThumbnail.height) {
        return true;
      }
    }

    return false;
  }

  void _scheduleScrollToActive({required bool immediate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _requestAutoScroll(immediate: immediate);
    });
  }

  void _requestAutoScroll({required bool immediate}) {
    if (!widget.isScrollLocked) {
      return;
    }
    if (immediate) {
      _cancelAutoScrollThrottle();
      _scrollToActive();
      return;
    }
    if (_autoScrollThrottleTimer == null) {
      _scrollToActive();
      _startAutoScrollThrottleWindow();
      return;
    }
    _hasPendingAutoScroll = true;
  }

  void _startAutoScrollThrottleWindow() {
    _autoScrollThrottleTimer?.cancel();
    _autoScrollThrottleTimer = Timer(_autoScrollThrottleDuration, () {
      if (!mounted) {
        return;
      }
      if (!_hasPendingAutoScroll || !widget.isScrollLocked) {
        _autoScrollThrottleTimer = null;
        _hasPendingAutoScroll = false;
        return;
      }
      _hasPendingAutoScroll = false;
      _scrollToActive();
      _startAutoScrollThrottleWindow();
    });
  }

  void _cancelAutoScrollThrottle() {
    _autoScrollThrottleTimer?.cancel();
    _autoScrollThrottleTimer = null;
    _hasPendingAutoScroll = false;
  }

  void _scrollToActive() {
    if (!widget.isScrollLocked) {
      return;
    }
    if (!_scrollController.hasClients) {
      _scheduleScrollToActive(immediate: true);
      return;
    }
    final activeIndex = widget.activeIndex;
    if (activeIndex == null ||
        activeIndex < 0 ||
        activeIndex >= widget.thumbnails.length) {
      return;
    }
    _scrollToActiveByLayout(activeIndex);
  }

  void _scrollToActiveByLayout(int activeIndex) {
    final gridSize = context.size;
    if (gridSize == null) {
      _scheduleScrollToActive(immediate: true);
      return;
    }

    final spacing = context.appSpacing.sm;
    final viewportDimension = _scrollController.position.viewportDimension;

    final double centeredOffset;
    if (widget.layout == ThumbnailGridLayout.staggered) {
      final layout = _ensureStaggeredLayout(gridSize.width, spacing);
      if (layout == null ||
          activeIndex < 0 ||
          activeIndex >= layout.tiles.length) {
        return;
      }
      final tile = layout.tiles[activeIndex];
      centeredOffset =
          tile.topOffset + tile.height / 2 - viewportDimension / 2;
    } else {
      final aspectRatio =
          context.appComponentTokens.moviePlayerThumbnailAspectRatio;
      final tileWidth =
          (gridSize.width - spacing * (widget.columns - 1)) / widget.columns;
      final tileHeight = tileWidth / aspectRatio;
      final rowExtent = tileHeight + spacing;
      final rowIndex = activeIndex ~/ widget.columns;
      centeredOffset =
          (rowIndex * rowExtent) - (viewportDimension - tileHeight) / 2;
    }

    final targetOffset = centeredOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    final distance = (_scrollController.offset - targetOffset).abs();
    if (distance < 1) {
      return;
    }

    if (distance > viewportDimension) {
      _scrollController.jumpTo(targetOffset);
      _markScrollSettled();
      return;
    }

    if (!_isUserScrollInProgress) {
      setState(() {
        _isUserScrollInProgress = true;
      });
    }
    _scrollIdleTimer?.cancel();
    _scrollController
        .animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (!mounted) {
            return;
          }
          _markScrollSettled();
        });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (widget.thumbnails.isEmpty || widget.isScrollLocked) {
      return false;
    }

    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    switch (notification) {
      case ScrollStartNotification():
      case ScrollUpdateNotification():
      case UserScrollNotification():
      case OverscrollNotification():
        _handleScrollUpdate(notification.metrics);
      case ScrollEndNotification():
        _scheduleScrollSettled();
    }

    return false;
  }

  void _handleScrollUpdate(ScrollMetrics metrics) {
    _scrollIdleTimer?.cancel();
    final rangeChanged = _updateVisibleIndexRange(metrics: metrics);
    if (_isUserScrollInProgress) {
      if (rangeChanged) {
        setState(() {});
      }
    } else {
      setState(() {
        _isUserScrollInProgress = true;
      });
    }
    _scheduleScrollSettled();
  }

  void _scheduleScrollSettled() {
    _scrollIdleTimer?.cancel();
    _scrollIdleTimer = Timer(_scrollIdleDuration, _markScrollSettled);
  }

  void _scheduleVisibleRangeRefreshIfLayoutChanged(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth ||
        !constraints.hasBoundedHeight ||
        !constraints.maxWidth.isFinite ||
        !constraints.maxHeight.isFinite ||
        constraints.maxWidth <= 0 ||
        constraints.maxHeight <= 0) {
      return;
    }

    final nextSize = Size(constraints.maxWidth, constraints.maxHeight);
    if (_lastGridLayoutSize == nextSize) {
      return;
    }
    _lastGridLayoutSize = nextSize;
    _scheduleVisibleRangeRefreshAfterLayout();
  }

  void _scheduleVisibleRangeRefreshAfterLayout() {
    if (_hasPendingVisibleRangeRefresh) {
      return;
    }
    _hasPendingVisibleRangeRefresh = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _hasPendingVisibleRangeRefresh = false;
      _markScrollSettled();
    });
  }

  void _markScrollSettled() {
    _scrollIdleTimer?.cancel();
    final rangeChanged = _updateVisibleIndexRange();
    if (!mounted) {
      return;
    }
    if (_isUserScrollInProgress || rangeChanged) {
      setState(() {
        _isUserScrollInProgress = false;
      });
    }
  }

  bool _updateVisibleIndexRange({ScrollMetrics? metrics}) {
    if (widget.thumbnails.isEmpty) {
      final changed = _visibleStartIndex != null ||
          _visibleEndIndex != null ||
          _staggeredVisibleIndices.isNotEmpty;
      _visibleStartIndex = null;
      _visibleEndIndex = null;
      _staggeredVisibleIndices.clear();
      _renderedImageIndices.clear();
      return changed;
    }

    final effectiveMetrics =
        metrics ??
        (_scrollController.hasClients ? _scrollController.position : null);
    final gridSize = context.size;
    if (effectiveMetrics == null || gridSize == null) {
      return false;
    }

    final spacing = context.appSpacing.sm;
    final viewportDimension = effectiveMetrics.viewportDimension;
    final offset = effectiveMetrics.pixels.clamp(
      effectiveMetrics.minScrollExtent,
      effectiveMetrics.maxScrollExtent,
    );

    if (widget.layout == ThumbnailGridLayout.staggered) {
      final layout = _ensureStaggeredLayout(gridSize.width, spacing);
      if (layout == null) {
        return false;
      }
      // 用 tile 自身高度算 buffer：buffer ~= _visibleRowBuffer 行 * 平均 tile 高。
      // 平均高取「总高 / 平均每列 tile 数」，与 uniform 分支按行缓冲粗略对齐。
      final averageTileHeight =
          layout.tiles.isEmpty
              ? 0.0
              : layout.tiles
                      .map((t) => t.height)
                      .reduce((a, b) => a + b) /
                  layout.tiles.length;
      final buffer = (averageTileHeight + spacing) * _visibleRowBuffer;
      final from = offset - buffer;
      final to = offset + viewportDimension + buffer;
      final nextVisible = <int>{};
      for (var i = 0; i < layout.tiles.length; i++) {
        final tile = layout.tiles[i];
        if (tile.bottomOffset < from) continue;
        if (tile.topOffset > to) continue;
        nextVisible.add(i);
      }
      final changed =
          nextVisible.length != _staggeredVisibleIndices.length ||
              !nextVisible.containsAll(_staggeredVisibleIndices);
      _staggeredVisibleIndices
        ..clear()
        ..addAll(nextVisible);
      return changed;
    }

    final aspectRatio =
        context.appComponentTokens.moviePlayerThumbnailAspectRatio;
    final tileWidth =
        (gridSize.width - spacing * (widget.columns - 1)) / widget.columns;
    final tileHeight = tileWidth / aspectRatio;
    final rowExtent = tileHeight + spacing;

    final startRow = (offset / rowExtent).floor();
    final endRow =
        ((offset + viewportDimension) / rowExtent).ceil().clamp(1, 1 << 20) - 1;
    final bufferedStartRow = (startRow - _visibleRowBuffer).clamp(0, 1 << 20);
    final bufferedEndRow = endRow + _visibleRowBuffer;
    final nextStart = bufferedStartRow * widget.columns;
    final nextEnd = (((bufferedEndRow + 1) * widget.columns) - 1).clamp(
      0,
      widget.thumbnails.length - 1,
    );

    final changed =
        _visibleStartIndex != nextStart || _visibleEndIndex != nextEnd;
    _visibleStartIndex = nextStart;
    _visibleEndIndex = nextEnd;
    return changed;
  }

  /// 瀑布流 layout 缓存：依赖 gridWidth + spacing + columns + thumbnails。任一变化
  /// 时由 `didUpdateWidget` 或 `_scheduleVisibleRangeRefreshAfterLayout` 清零，下次
  /// 调用时按当前快照重算一次并复用。
  StaggeredLayoutResult? _ensureStaggeredLayout(double gridWidth, double spacing) {
    if (gridWidth <= 0 || widget.thumbnails.isEmpty) {
      return null;
    }
    final cached = _staggeredLayout;
    // 命中需同时满足帧数与 grid 宽度一致：宽度变了（分栏拖动 / 窗口缩放）即使帧数没变
    // 也必须按新宽重算，否则 tile 的 topOffset/height 仍是旧宽算出、与实际渲染脱节。
    if (cached != null &&
        cached.tiles.length == widget.thumbnails.length &&
        _staggeredLayoutWidth == gridWidth) {
      return cached;
    }
    final items =
        widget.thumbnails
            .map(
              (t) => (width: t.width, height: t.height),
            )
            .toList(growable: false);
    final result = computeStaggeredLayout(
      crossAxisCount: widget.columns,
      availableWidth: gridWidth,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      items: items,
    );
    _staggeredLayout = result;
    _staggeredLayoutWidth = gridWidth;
    return result;
  }

  bool _shouldBuildImageForIndex(int index) {
    // 已加载过的保持渲染，避免来回滚动时反复变回占位图。
    if (_renderedImageIndices.contains(index)) {
      return true;
    }
    // 在（带上下缓冲的）可见范围内即建图，滚动过程中也立即加载，不再等手指离开。
    if (!_isWithinVisibleRange(index)) {
      return false;
    }
    _renderedImageIndices.add(index);
    return true;
  }

  bool _isWithinClipBand(int index) {
    final start = widget.clipStartIndex;
    final end = widget.clipEndIndex;
    if (start == null || end == null) {
      return false;
    }
    final lo = start < end ? start : end;
    final hi = start < end ? end : start;
    return index >= lo && index <= hi;
  }

  bool _isWithinVisibleRange(int index) {
    if (widget.layout == ThumbnailGridLayout.staggered) {
      // 首帧未算过 layout（_staggeredVisibleIndices 空且没失效标记）时放行，让首屏可见。
      if (_staggeredVisibleIndices.isEmpty && _staggeredLayout == null) {
        return true;
      }
      return _staggeredVisibleIndices.contains(index);
    }
    final visibleStartIndex = _visibleStartIndex;
    final visibleEndIndex = _visibleEndIndex;
    if (visibleStartIndex == null || visibleEndIndex == null) {
      return true;
    }
    return index >= visibleStartIndex && index <= visibleEndIndex;
  }

  ({int? width, int? height}) _resolveDecodeHint(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth ||
        !constraints.maxWidth.isFinite ||
        constraints.maxWidth <= 0) {
      return (width: null, height: null);
    }
    if (!constraints.hasBoundedHeight ||
        !constraints.maxHeight.isFinite ||
        constraints.maxHeight <= 0) {
      return (width: null, height: null);
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final effectiveDevicePixelRatio = dpr.clamp(
      1.0,
      _decodeDevicePixelRatioCap,
    );
    final cacheWidth = ((constraints.maxWidth * effectiveDevicePixelRatio)
        .round()
        .clamp(1, _decodeSizeUpperBound));
    // 只按宽给解码提示、不给高：ResizeImage 默认 exact 策略下同时给宽高会把位图
    // **强制拉伸**成 tile 的 16:9（既毁了竖图渲染，也让宽高比检测恒为 ~1.78）。
    // 单边宽 → 保持原图宽高比，cover/contain 与自适应 fit 检测才正确。
    return (width: cacheWidth, height: null);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _MovieMediaThumbnailGridSkeleton(
        columns: widget.columns,
        keyPrefix: widget.keyPrefix,
      );
    }
    if (widget.errorMessage != null) {
      return _MovieMediaThumbnailErrorState(
        keyPrefix: widget.keyPrefix,
        message: widget.errorMessage!,
        onRetry: widget.onRetry,
      );
    }
    if (widget.thumbnails.isEmpty) {
      return const Center(child: AppEmptyState(message: '还没有可用缩略图'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _scheduleVisibleRangeRefreshIfLayoutChanged(constraints);
        return NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child:
              widget.layout == ThumbnailGridLayout.staggered
                  ? _buildStaggeredGrid(context)
                  : _buildUniformGrid(context),
        );
      },
    );
  }

  Widget _buildUniformGrid(BuildContext context) {
    return GridView.builder(
      key: Key('${widget.keyPrefix}-thumbnail-grid'),
      controller: _scrollController,
      cacheExtent: 500,
      physics:
          widget.isScrollLocked
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.columns,
        crossAxisSpacing: context.appSpacing.sm,
        mainAxisSpacing: context.appSpacing.sm,
        childAspectRatio:
            context.appComponentTokens.moviePlayerThumbnailAspectRatio,
      ),
      itemCount: widget.thumbnails.length,
      itemBuilder:
          (context, index) =>
              _buildTile(context, index, useAdaptiveFit: true, aspect: null),
    );
  }

  Widget _buildStaggeredGrid(BuildContext context) {
    final spacing = context.appSpacing.sm;
    return CustomScrollView(
      key: Key('${widget.keyPrefix}-thumbnail-grid'),
      controller: _scrollController,
      cacheExtent: 500,
      physics:
          widget.isScrollLocked
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
      slivers: [
        SliverMasonryGrid.count(
          crossAxisCount: widget.columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childCount: widget.thumbnails.length,
          itemBuilder: (context, index) {
            final thumbnail = widget.thumbnails[index];
            final w = thumbnail.width;
            final h = thumbnail.height;
            final aspect =
                (w != null && h != null && w > 0 && h > 0)
                    ? w / h
                    : _kStaggeredFallbackAspect;
            // AspectRatio 让 SliverMasonryGrid 无须解码图片即可定 tile 高度，懒构建照常生效。
            return AspectRatio(
              aspectRatio: aspect,
              child: _buildTile(
                context,
                index,
                useAdaptiveFit: false,
                aspect: aspect,
              ),
            );
          },
        ),
      ],
    );
  }

  /// 单 tile：装饰边框 + 切片端点 badge + 图片或占位 + 点击/菜单交互。
  /// [useAdaptiveFit]=true 走 uniform 分支的运行时测图选 fit；
  /// [useAdaptiveFit]=false（staggered 分支）按已知 [aspect] 切 tile，图片直接 `BoxFit.cover`。
  Widget _buildTile(
    BuildContext context,
    int index, {
    required bool useAdaptiveFit,
    required double? aspect,
  }) {
    final thumbnail = widget.thumbnails[index];
    final isActive = widget.activeIndex == index;
    final isClipStart = widget.clipStartIndex == index;
    final isClipEnd = widget.clipEndIndex == index;
    final isClipEndpoint = isClipStart || isClipEnd;
    final isInClipBand = _isWithinClipBand(index);
    final primary = Theme.of(context).colorScheme.primary;

    final Color tileColor;
    final Color borderColor;
    final double borderWidth;
    if (isClipEndpoint) {
      tileColor = primary.withValues(alpha: 0.18);
      borderColor = primary;
      borderWidth = 2.5;
    } else if (isInClipBand) {
      tileColor = primary.withValues(alpha: 0.10);
      borderColor = primary.withValues(alpha: 0.45);
      borderWidth = 1.5;
    } else if (isActive) {
      tileColor = primary.withValues(alpha: 0.08);
      borderColor = primary;
      borderWidth = 1.5;
    } else {
      tileColor = context.appColors.surfaceCard;
      borderColor = context.appColors.borderSubtle;
      borderWidth = 1;
    }

    final image =
        _shouldBuildImageForIndex(index)
            ? LayoutBuilder(
              builder: (context, constraints) {
                final decodeHint = _resolveDecodeHint(constraints);
                if (useAdaptiveFit) {
                  return _AdaptiveFitThumbnailImage(
                    url: thumbnail.image.bestAvailableUrl,
                    memCacheWidth: decodeHint.width,
                    memCacheHeight: decodeHint.height,
                  );
                }
                // 瀑布流分支按真实比例切 tile，cover 不再裁掉关键内容。
                return MaskedImage(
                  url: thumbnail.image.bestAvailableUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: decodeHint.width,
                  memCacheHeight: decodeHint.height,
                );
              },
            )
            : const _MovieMediaThumbnailImagePlaceholder();

    final child = KeyedSubtree(
      key: Key('${widget.keyPrefix}-thumb-$index'),
      child: DecoratedBox(
        key: Key('${widget.keyPrefix}-thumbnail-tile-$index-decoration'),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: context.appRadius.xsBorder,
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow:
              (isActive || isClipEndpoint) ? context.appShadows.panel : null,
        ),
        child: ClipRRect(
          borderRadius: context.appRadius.xsBorder,
          child:
              isClipEndpoint
                  ? Stack(
                    fit: StackFit.expand,
                    children: [
                      image,
                      Positioned(
                        top: 4,
                        left: 4,
                        child: _ClipEndpointBadge(
                          label: isClipStart ? '起' : '终',
                        ),
                      ),
                    ],
                  )
                  : image,
        ),
      ),
    );

    final menuHandler = widget.onThumbnailMenuRequested;
    if (menuHandler == null) {
      return GestureDetector(
        onTap: () => widget.onThumbnailTap(index),
        child: child,
      );
    }

    return AppImageActionTrigger(
      onTap: () => widget.onThumbnailTap(index),
      onRequestMenu: (globalPosition) => menuHandler(index, globalPosition),
      child: child,
    );
  }
}

class _ClipEndpointBadge extends StatelessWidget {
  const _ClipEndpointBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: EdgeInsets.all(context.appSpacing.xs),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: context.appRadius.xsBorder,
      ),
      child: Text(
        label,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.semibold,
          tone: AppTextTone.primary,
        ).copyWith(color: Theme.of(context).colorScheme.onPrimary),
      ),
    );
  }
}

/// 关键帧缩略图：测得真实宽高比后选 cover/contain，再交标准入口 [MaskedImage] 渲染。
///
/// 单独起一个测量 provider（与 [MaskedImage] 同 url、同 decode 提示 → 共享解码缓存键，
/// 不触发额外整图解码），用既有「`ImageStreamListener` 读 `ImageInfo` 真实尺寸」范式
/// （对齐 `MoviePlotThumbnail`）。blur / 占位 / URL 解析仍全部走 [MaskedImage]。
class _AdaptiveFitThumbnailImage extends StatefulWidget {
  const _AdaptiveFitThumbnailImage({
    required this.url,
    required this.memCacheWidth,
    required this.memCacheHeight,
  });

  final String url;
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  State<_AdaptiveFitThumbnailImage> createState() =>
      _AdaptiveFitThumbnailImageState();
}

class _AdaptiveFitThumbnailImageState
    extends State<_AdaptiveFitThumbnailImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  ImageProvider<Object>? _measureProvider;
  double? _aspectRatio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveMeasureProvider();
  }

  @override
  void didUpdateWidget(covariant _AdaptiveFitThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.memCacheWidth != widget.memCacheWidth ||
        oldWidget.memCacheHeight != widget.memCacheHeight) {
      _resolveMeasureProvider();
    }
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  void _resolveMeasureProvider() {
    final provider = _buildMeasureProvider();
    if (_measureProvider == provider) {
      return;
    }
    _measureProvider = provider;
    // 换 url：先回退 cover，待新图测得再切。
    _aspectRatio = null;
    _listen(provider);
  }

  ImageProvider<Object>? _buildMeasureProvider() {
    final baseUrl = context.read<SessionStore>().baseUrl;
    final resolvedUrl = resolveMediaUrl(rawUrl: widget.url, baseUrl: baseUrl);
    if (resolvedUrl == null) {
      // 与 MaskedImage 的 null 处理一致：不测量，由 MaskedImage 自渲占位。
      return null;
    }
    final base = CachedNetworkImageProvider(resolvedUrl);
    // 镜像 CachedNetworkImage 传入 memCacheWidth/Height 时的内部 ResizeImage 包装，
    // 用相同尺寸 → 与 MaskedImage 共享同一解码缓存键。
    if (widget.memCacheWidth == null && widget.memCacheHeight == null) {
      return base;
    }
    return ResizeImage(
      base,
      width: widget.memCacheWidth,
      height: widget.memCacheHeight,
      allowUpscaling: false,
    );
  }

  void _listen(ImageProvider<Object>? provider) {
    _stopListening();
    if (provider == null) {
      return;
    }
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((ImageInfo info, bool _) {
      final width = info.image.width.toDouble();
      final height = info.image.height.toDouble();
      if (!mounted || width <= 0 || height <= 0) {
        return;
      }
      final ratio = width / height;
      if (_aspectRatio == ratio) {
        return;
      }
      setState(() => _aspectRatio = ratio);
    });
    stream.addListener(listener);
    _imageStream = stream;
    _imageStreamListener = listener;
  }

  void _stopListening() {
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  @override
  Widget build(BuildContext context) {
    return MaskedImage(
      url: widget.url,
      fit: resolveAdaptiveThumbnailFit(_aspectRatio),
      memCacheWidth: widget.memCacheWidth,
      memCacheHeight: widget.memCacheHeight,
    );
  }
}

class _MovieMediaThumbnailImagePlaceholder extends StatelessWidget {
  const _MovieMediaThumbnailImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surfaceMuted),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: componentTokens.iconSize3xl,
          color: context.appTextPalette.muted,
        ),
      ),
    );
  }
}

class _MovieMediaThumbnailErrorState extends StatelessWidget {
  const _MovieMediaThumbnailErrorState({
    required this.keyPrefix,
    required this.message,
    required this.onRetry,
  });

  final String keyPrefix;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: context.appComponentTokens.iconSize2xl,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(height: context.appSpacing.lg),
            Text(
              '缩略图加载失败',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s18,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            SizedBox(height: context.appSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
            SizedBox(height: context.appSpacing.lg),
            AppButton(
              key: Key('$keyPrefix-thumbnail-retry'),
              label: '重试',
              variant: AppButtonVariant.secondary,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _MovieMediaThumbnailGridSkeleton extends StatelessWidget {
  const _MovieMediaThumbnailGridSkeleton({
    required this.columns,
    required this.keyPrefix,
  });

  final int columns;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: Key('$keyPrefix-thumbnail-grid-skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: context.appSpacing.sm,
        mainAxisSpacing: context.appSpacing.sm,
        childAspectRatio:
            context.appComponentTokens.moviePlayerThumbnailAspectRatio,
      ),
      itemCount: columns * 4,
      itemBuilder: (context, index) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: context.appColors.surfaceMuted,
            borderRadius: context.appRadius.mdBorder,
          ),
        );
      },
    );
  }
}
