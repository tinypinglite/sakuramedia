import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/app_image_action_trigger.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

/// pornbox 关键帧多为竖图；宽高比 < 此阈值时用 contain 完整展示，否则 cover 填满 tile。
const double _kAdaptiveFitAspectThreshold = 1.5;

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
        oldWidget.columns != widget.columns) {
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
              nextThumbnail.image.bestAvailableUrl) {
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
    final aspectRatio =
        context.appComponentTokens.moviePlayerThumbnailAspectRatio;
    final tileWidth =
        (gridSize.width - spacing * (widget.columns - 1)) / widget.columns;
    final tileHeight = tileWidth / aspectRatio;
    final rowExtent = tileHeight + spacing;
    final rowIndex = activeIndex ~/ widget.columns;
    final viewportDimension = _scrollController.position.viewportDimension;
    final centeredOffset =
        (rowIndex * rowExtent) - (viewportDimension - tileHeight) / 2;
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
      final changed = _visibleStartIndex != null || _visibleEndIndex != null;
      _visibleStartIndex = null;
      _visibleEndIndex = null;
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
    final aspectRatio =
        context.appComponentTokens.moviePlayerThumbnailAspectRatio;
    final tileWidth =
        (gridSize.width - spacing * (widget.columns - 1)) / widget.columns;
    final tileHeight = tileWidth / aspectRatio;
    final rowExtent = tileHeight + spacing;
    final viewportDimension = effectiveMetrics.viewportDimension;
    final offset = effectiveMetrics.pixels.clamp(
      effectiveMetrics.minScrollExtent,
      effectiveMetrics.maxScrollExtent,
    );

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
          child: GridView.builder(
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
            itemBuilder: (context, index) {
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
                          return _AdaptiveFitThumbnailImage(
                            url: thumbnail.image.bestAvailableUrl,
                            memCacheWidth: decodeHint.width,
                            memCacheHeight: decodeHint.height,
                          );
                        },
                      )
                      : const _MovieMediaThumbnailImagePlaceholder();

              final child = KeyedSubtree(
                key: Key('${widget.keyPrefix}-thumb-$index'),
                child: DecoratedBox(
                  key: Key(
                    '${widget.keyPrefix}-thumbnail-tile-$index-decoration',
                  ),
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: context.appRadius.xsBorder,
                    border: Border.all(color: borderColor, width: borderWidth),
                    boxShadow:
                        (isActive || isClipEndpoint)
                            ? context.appShadows.panel
                            : null,
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
                onRequestMenu:
                    (globalPosition) => menuHandler(index, globalPosition),
                child: child,
              );
            },
          ),
        );
      },
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
