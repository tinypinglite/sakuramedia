import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/app_image_action_trigger.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

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
    this.keyPrefix = 'movie-media',
  });

  final List<MovieMediaThumbnailDto> thumbnails;
  final bool isLoading;
  final String? errorMessage;
  final int columns;
  final int? activeIndex;
  final bool isScrollLocked;
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
  static const int _visibleRowBuffer = 1;
  static const double _decodeDevicePixelRatioCap = 2.0;
  static const int _decodeSizeUpperBound = 1024;

  late final ScrollController _scrollController;
  Timer? _scrollIdleTimer;
  Timer? _autoScrollThrottleTimer;
  bool _isUserScrollInProgress = false;
  bool _hasPendingAutoScroll = false;
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
    if (oldWidget.thumbnails.length != widget.thumbnails.length &&
        !widget.isScrollLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _markScrollSettled();
      });
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
    final isInVisibleRange = _isWithinVisibleRange(index);
    if (_isUserScrollInProgress) {
      return _renderedImageIndices.contains(index);
    }
    if (!isInVisibleRange) {
      return false;
    }
    _renderedImageIndices.add(index);
    return true;
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
    final effectiveDevicePixelRatio =
        dpr.clamp(1.0, _decodeDevicePixelRatioCap) as double;
    final cacheWidth =
        ((constraints.maxWidth * effectiveDevicePixelRatio).round()).clamp(
              1,
              _decodeSizeUpperBound,
            )
            as int;
    final cacheHeight =
        ((constraints.maxHeight * effectiveDevicePixelRatio).round()).clamp(
              1,
              _decodeSizeUpperBound,
            )
            as int;
    return (width: cacheWidth, height: cacheHeight);
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

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: GridView.builder(
        key: Key('${widget.keyPrefix}-thumbnail-grid'),
        controller: _scrollController,
        cacheExtent: 240,
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

          final child = KeyedSubtree(
            key: Key('${widget.keyPrefix}-thumb-$index'),
            child: DecoratedBox(
              key: Key('${widget.keyPrefix}-thumbnail-tile-$index-decoration'),
              decoration: BoxDecoration(
                color:
                    isActive
                        ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08)
                        : context.appColors.surfaceCard,
                borderRadius: context.appRadius.xsBorder,
                border: Border.all(
                  color:
                      isActive
                          ? Theme.of(context).colorScheme.primary
                          : context.appColors.borderSubtle,
                  width: isActive ? 1.5 : 1,
                ),
                boxShadow: isActive ? context.appShadows.panel : null,
              ),
              child: ClipRRect(
                borderRadius: context.appRadius.xsBorder,
                child:
                    _shouldBuildImageForIndex(index)
                        ? LayoutBuilder(
                          builder: (context, constraints) {
                            final decodeHint = _resolveDecodeHint(constraints);
                            return MaskedImage(
                              url: thumbnail.image.bestAvailableUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: decodeHint.width,
                              memCacheHeight: decodeHint.height,
                            );
                          },
                        )
                        : const _MovieMediaThumbnailImagePlaceholder(),
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
