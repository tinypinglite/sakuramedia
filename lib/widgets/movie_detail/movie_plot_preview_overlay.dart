import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:sakuramedia/config/app_image_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/media/app_image_fullscreen.dart';
import 'package:sakuramedia/widgets/media/app_image_action_trigger.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';
import 'package:sakuramedia/widgets/media/preview_dialog_surface.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_plot_thumbnail.dart';

enum MoviePlotPreviewThumbnailStripLayout { adaptive, fixed }

enum MoviePlotPreviewPresentation { dialog, bottomDrawer }

// 移动端剧情图预览底部抽屉高度比例，可在这里统一调整。
const double kMoviePlotPreviewDrawerHeightFactor = 0.7;

Future<void> showMoviePlotPreviewOverlay({
  required BuildContext context,
  required List<MovieImageDto> plotImages,
  required int initialIndex,
  Future<void> Function(BuildContext context, int index, Offset globalPosition)?
  onRequestImageMenu,
  MoviePlotPreviewPresentation presentation =
      MoviePlotPreviewPresentation.dialog,
  MoviePlotPreviewThumbnailStripLayout thumbnailStripLayout =
      MoviePlotPreviewThumbnailStripLayout.adaptive,
}) {
  if (plotImages.isEmpty) {
    return Future<void>.value();
  }

  switch (presentation) {
    case MoviePlotPreviewPresentation.dialog:
      return showDialog<void>(
        context: context,
        builder:
            (dialogContext) => _MoviePlotPreviewDialog(
              plotImages: plotImages,
              initialIndex: initialIndex,
              onRequestImageMenu: onRequestImageMenu,
              thumbnailStripLayout: thumbnailStripLayout,
              enablePinchToFullscreen: false,
            ),
      );
    case MoviePlotPreviewPresentation.bottomDrawer:
      return showAppBottomDrawer<void>(
        context: context,
        drawerKey: const Key('movie-plot-preview-bottom-drawer'),
        heightFactor: kMoviePlotPreviewDrawerHeightFactor,
        ignoreTopSafeArea: true,
        builder:
            (sheetContext) => _MoviePlotPreviewContent(
              plotImages: plotImages,
              initialIndex: initialIndex,
              onRequestImageMenu: onRequestImageMenu,
              thumbnailStripLayout: thumbnailStripLayout,
              enablePinchToFullscreen: isMobileAppPlatform(),
            ),
      );
  }
}

class _MoviePlotPreviewDialog extends StatelessWidget {
  const _MoviePlotPreviewDialog({
    required this.plotImages,
    required this.initialIndex,
    required this.onRequestImageMenu,
    required this.thumbnailStripLayout,
    required this.enablePinchToFullscreen,
  });

  final List<MovieImageDto> plotImages;
  final int initialIndex;
  final Future<void> Function(
    BuildContext context,
    int index,
    Offset globalPosition,
  )?
  onRequestImageMenu;
  final MoviePlotPreviewThumbnailStripLayout thumbnailStripLayout;
  final bool enablePinchToFullscreen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appComponentTokens;
    final screenSize = MediaQuery.sizeOf(context);

    final maxWidth = math.min(
      screenSize.width - 64,
      tokens.movieDetailPlotPreviewMaxWidth,
    );
    final maxHeight = math.min(
      screenSize.height - 64,
      tokens.movieDetailPlotPreviewMaxHeight,
    );

    return PreviewDialogSurface(
      dialogKey: const Key('movie-plot-preview-dialog'),
      backgroundColor: context.appColors.surfaceCard,
      insetPadding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.xxl,
        vertical: context.appSpacing.xxl,
      ),
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: _MoviePlotPreviewContent(
        plotImages: plotImages,
        initialIndex: initialIndex,
        onRequestImageMenu: onRequestImageMenu,
        thumbnailStripLayout: thumbnailStripLayout,
        enablePinchToFullscreen: enablePinchToFullscreen,
      ),
    );
  }
}

class _MoviePlotPreviewContent extends StatefulWidget {
  const _MoviePlotPreviewContent({
    required this.plotImages,
    required this.initialIndex,
    required this.onRequestImageMenu,
    required this.thumbnailStripLayout,
    required this.enablePinchToFullscreen,
  });

  final List<MovieImageDto> plotImages;
  final int initialIndex;
  final Future<void> Function(
    BuildContext context,
    int index,
    Offset globalPosition,
  )?
  onRequestImageMenu;
  final MoviePlotPreviewThumbnailStripLayout thumbnailStripLayout;
  final bool enablePinchToFullscreen;

  @override
  State<_MoviePlotPreviewContent> createState() =>
      _MoviePlotPreviewContentState();
}

class _MoviePlotPreviewContentState extends State<_MoviePlotPreviewContent> {
  late final PageController _pageController;
  late final FocusNode _focusNode;
  late final ScrollController _thumbnailScrollController;
  late List<GlobalKey> _thumbnailKeys;
  late int _currentIndex;
  bool _hasSyncedInitialThumbnailStrip = false;
  bool _isFullscreenActive = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = _normalizeIndex(widget.initialIndex);
    _pageController = PageController(initialPage: _currentIndex);
    _focusNode = FocusNode();
    _thumbnailScrollController = ScrollController();
    _thumbnailKeys = List<GlobalKey>.generate(
      widget.plotImages.length,
      (_) => GlobalKey(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _focusNode.requestFocus();
      _scrollThumbnailsToCurrent();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _focusNode.dispose();
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MoviePlotPreviewContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plotImages.length != widget.plotImages.length) {
      _hasSyncedInitialThumbnailStrip = false;
      _thumbnailKeys = List<GlobalKey>.generate(
        widget.plotImages.length,
        (_) => GlobalKey(),
      );
    }
  }

  int _normalizeIndex(int index) {
    if (widget.plotImages.isEmpty) {
      return 0;
    }
    return index.clamp(0, widget.plotImages.length - 1);
  }

  void _goToIndex(int index) {
    final normalized = _normalizeIndex(index);
    if (normalized == _currentIndex) {
      return;
    }
    setState(() {
      _currentIndex = normalized;
    });
    _pageController.animateToPage(
      normalized,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
    _scrollThumbnailsToCurrent();
  }

  void _syncFullscreenImageIndex(int index) {
    final normalized = _normalizeIndex(index);
    if (normalized == _currentIndex) {
      return;
    }

    setState(() {
      _currentIndex = normalized;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(normalized);
    }
    _scrollThumbnailsToCurrent();
  }

  void _scrollThumbnailsToCurrent() {
    if (widget.thumbnailStripLayout ==
        MoviePlotPreviewThumbnailStripLayout.fixed) {
      _scrollFixedWidthThumbnailsToCurrent();
      return;
    }

    if (_thumbnailKeys.isEmpty || _currentIndex >= _thumbnailKeys.length) {
      return;
    }

    final targetContext = _thumbnailKeys[_currentIndex].currentContext;
    if (targetContext == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollThumbnailsToCurrent();
        }
      });
      return;
    }

    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: 0.5,
    );
  }

  void _scrollFixedWidthThumbnailsToCurrent() {
    if (!_thumbnailScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollFixedWidthThumbnailsToCurrent();
        }
      });
      return;
    }

    final spacing = context.appSpacing.sm;
    final itemWidth =
        context.appComponentTokens.movieDetailPlotPreviewThumbnailWidth;
    final itemExtent = itemWidth + spacing;
    final viewportWidth = _thumbnailScrollController.position.viewportDimension;
    final centeredOffset =
        (_currentIndex * itemExtent) - (viewportWidth - itemWidth) / 2;
    final targetOffset = centeredOffset.clamp(
      0.0,
      _thumbnailScrollController.position.maxScrollExtent,
    );

    final distance = (_thumbnailScrollController.offset - targetOffset).abs();
    if (distance < 1) {
      return;
    }

    if (!_hasSyncedInitialThumbnailStrip) {
      _hasSyncedInitialThumbnailStrip = true;
      _thumbnailScrollController.jumpTo(targetOffset);
      return;
    }

    _thumbnailScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _goToIndex(_currentIndex - 1);
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _goToIndex(_currentIndex + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final fullscreenGalleryItems = widget.plotImages
        .map((image) => AppFullscreenImageItem(url: image.bestAvailableUrl))
        .toList(growable: false);

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        children: [
          Padding(
            padding:
                isMobileAppPlatform()
                    ? EdgeInsets.symmetric(horizontal: spacing.md)
                    : EdgeInsets.all(spacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_currentIndex + 1} / ${widget.plotImages.length}',
                    key: const Key('movie-plot-preview-counter'),
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // SizedBox(height: spacing.md),
          Expanded(
            child: PageView.builder(
              key: const Key('movie-plot-preview-page-view'),
              controller: _pageController,
              physics:
                  _isFullscreenActive
                      ? const NeverScrollableScrollPhysics()
                      : null,
              itemCount: widget.plotImages.length,
              onPageChanged: (index) {
                if (_currentIndex == index) {
                  return;
                }
                setState(() {
                  _currentIndex = index;
                });
                _scrollThumbnailsToCurrent();
              },
              itemBuilder: (context, index) {
                final image = widget.plotImages[index];
                return _PreviewMainImageActionTarget(
                  key: Key('movie-plot-preview-main-image-$index'),
                  imageUrl: image.bestAvailableUrl,
                  fullscreenGalleryItems: fullscreenGalleryItems,
                  fullscreenGalleryIndex: index,
                  onFullscreenImageIndexChanged: _syncFullscreenImageIndex,
                  fallbackAspectRatio:
                      tokens.movieDetailPlotThumbnailWidth /
                      tokens.movieDetailPlotThumbnailHeight,
                  enablePinchToFullscreen: widget.enablePinchToFullscreen,
                  onFullscreenChanged: (isActive) {
                    if (!mounted || _isFullscreenActive == isActive) {
                      return;
                    }
                    setState(() {
                      _isFullscreenActive = isActive;
                    });
                  },
                  onRequestMenu:
                      widget.onRequestImageMenu == null
                          ? null
                          : (previewIndex, globalPosition) =>
                              widget.onRequestImageMenu!(
                                context,
                                previewIndex,
                                globalPosition,
                              ),
                );
              },
            ),
          ),
          SizedBox(height: spacing.md),
          IgnorePointer(
            ignoring: _isFullscreenActive,
            child: SizedBox(
              height:
                  tokens.movieDetailPlotPreviewThumbnailHeight + spacing.xs * 2,
              child: ListView.separated(
                key: const Key('movie-plot-preview-thumbnail-list'),
                controller: _thumbnailScrollController,
                scrollDirection: Axis.horizontal,
                itemCount: widget.plotImages.length,
                separatorBuilder: (_, __) => SizedBox(width: spacing.sm),
                itemBuilder: (context, index) {
                  final image = widget.plotImages[index];
                  final isCurrent = index == _currentIndex;
                  final animatedThumbnail = AnimatedScale(
                    key: _thumbnailKeys[index],
                    duration: const Duration(milliseconds: 180),
                    scale: isCurrent ? 1.0 : 0.94,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: isCurrent ? 1 : 0.58,
                      child: _PreviewStripThumbnail(
                        image: image,
                        thumbnailStripLayout: widget.thumbnailStripLayout,
                      ),
                    ),
                  );
                  return widget.onRequestImageMenu == null
                      ? GestureDetector(
                        key: Key('movie-plot-preview-thumb-$index'),
                        onTap: () => _goToIndex(index),
                        child: animatedThumbnail,
                      )
                      : AppImageActionTrigger(
                        key: Key('movie-plot-preview-thumb-$index'),
                        onTap: () => _goToIndex(index),
                        onRequestMenu:
                            (globalPosition) => widget.onRequestImageMenu!(
                              context,
                              index,
                              globalPosition,
                            ),
                        child: animatedThumbnail,
                      );
                },
              ),
            ),
          ),
          SizedBox(height: spacing.md),
        ],
      ),
    );
  }
}

class _PreviewStripThumbnail extends StatelessWidget {
  const _PreviewStripThumbnail({
    required this.image,
    required this.thumbnailStripLayout,
  });

  final MovieImageDto image;
  final MoviePlotPreviewThumbnailStripLayout thumbnailStripLayout;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appComponentTokens;

    final thumbnail = MoviePlotThumbnail(
      maxHeight: tokens.movieDetailPlotPreviewThumbnailHeight,
      fallbackAspectRatio:
          tokens.movieDetailPlotPreviewThumbnailWidth /
          tokens.movieDetailPlotPreviewThumbnailHeight,
      borderRadius: context.appRadius.mdBorder,
      url: image.bestAvailableUrl,
    );

    return switch (thumbnailStripLayout) {
      MoviePlotPreviewThumbnailStripLayout.adaptive => thumbnail,
      MoviePlotPreviewThumbnailStripLayout.fixed => SizedBox(
        width: tokens.movieDetailPlotPreviewThumbnailWidth,
        child: thumbnail,
      ),
    };
  }
}

class _PreviewMainImageActionTarget extends StatefulWidget {
  const _PreviewMainImageActionTarget({
    super.key,
    required this.imageUrl,
    required this.fullscreenGalleryItems,
    required this.fullscreenGalleryIndex,
    required this.fallbackAspectRatio,
    required this.enablePinchToFullscreen,
    this.onFullscreenImageIndexChanged,
    this.onFullscreenChanged,
    this.onRequestMenu,
  });

  final String imageUrl;
  final List<AppFullscreenImageItem> fullscreenGalleryItems;
  final int fullscreenGalleryIndex;
  final double fallbackAspectRatio;
  final bool enablePinchToFullscreen;
  final ValueChanged<int>? onFullscreenImageIndexChanged;
  final ValueChanged<bool>? onFullscreenChanged;
  final void Function(int index, Offset globalPosition)? onRequestMenu;

  @override
  State<_PreviewMainImageActionTarget> createState() =>
      _PreviewMainImageActionTargetState();
}

class _PreviewMainImageActionTargetState
    extends State<_PreviewMainImageActionTarget> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  ImageProvider<Object>? _resolvedImageProvider;
  double? _imageAspectRatio;
  bool _suppressMenuRequests = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImageProvider();
  }

  @override
  void didUpdateWidget(covariant _PreviewMainImageActionTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolveImageProvider();
    }
  }

  @override
  void dispose() {
    _stopListeningToImageStream();
    super.dispose();
  }

  void _resolveImageProvider() {
    final baseUrl = context.read<SessionStore>().baseUrl;
    final resolvedUrl = resolveMediaUrl(
      rawUrl: widget.imageUrl,
      baseUrl: baseUrl,
    );
    if (resolvedUrl == null) {
      _stopListeningToImageStream();
      if (_resolvedImageProvider != null || _imageAspectRatio != null) {
        setState(() {
          _resolvedImageProvider = null;
          _imageAspectRatio = null;
        });
      }
      return;
    }

    final nextProvider = CachedNetworkImageProvider(
      resolvedUrl,
      cacheManager: AppImageConfig.networkImageCacheManager,
    );
    if (_resolvedImageProvider == nextProvider) {
      return;
    }

    _resolvedImageProvider = nextProvider;
    _imageAspectRatio = null;
    _listenToImageStream(nextProvider);
  }

  void _listenToImageStream(ImageProvider<Object> provider) {
    _stopListeningToImageStream();

    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((
      ImageInfo imageInfo,
      bool synchronousCall,
    ) {
      final width = imageInfo.image.width.toDouble();
      final height = imageInfo.image.height.toDouble();
      if (!mounted || width <= 0 || height <= 0) {
        return;
      }

      final nextAspectRatio = width / height;
      if (_imageAspectRatio == nextAspectRatio) {
        return;
      }
      setState(() {
        _imageAspectRatio = nextAspectRatio;
      });
    });

    stream.addListener(listener);
    _imageStream = stream;
    _imageStreamListener = listener;
  }

  void _stopListeningToImageStream() {
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  void _requestMenuIfHit({
    required Offset localPosition,
    required Offset globalPosition,
  }) {
    final callback = widget.onRequestMenu;
    if (callback == null || _suppressMenuRequests) {
      return;
    }

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }

    if (!_isWithinRenderedImage(localPosition, renderObject.size)) {
      return;
    }

    callback(widget.fullscreenGalleryIndex, globalPosition);
  }

  bool _isWithinRenderedImage(Offset localPosition, Size viewportSize) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) {
      return false;
    }

    final resolvedAspectRatio =
        (_imageAspectRatio != null && _imageAspectRatio! > 0)
            ? _imageAspectRatio!
            : widget.fallbackAspectRatio;
    if (resolvedAspectRatio <= 0) {
      return false;
    }

    final viewportAspectRatio = viewportSize.width / viewportSize.height;
    late final double imageWidth;
    late final double imageHeight;

    if (viewportAspectRatio > resolvedAspectRatio) {
      imageHeight = viewportSize.height;
      imageWidth = imageHeight * resolvedAspectRatio;
    } else {
      imageWidth = viewportSize.width;
      imageHeight = imageWidth / resolvedAspectRatio;
    }

    final imageRect = Rect.fromLTWH(
      (viewportSize.width - imageWidth) / 2,
      (viewportSize.height - imageHeight) / 2,
      imageWidth,
      imageHeight,
    );
    return imageRect.contains(localPosition);
  }

  @override
  Widget build(BuildContext context) {
    return AppPinchToFullscreenImage(
      enabled: widget.enablePinchToFullscreen,
      url: widget.imageUrl,
      imageProvider: _resolvedImageProvider,
      imageAspectRatio: _imageAspectRatio,
      fallbackAspectRatio: widget.fallbackAspectRatio,
      fit: BoxFit.contain,
      fullscreenImageKey: const Key('movie-plot-preview-fullscreen-image'),
      fullscreenGalleryItems: widget.fullscreenGalleryItems,
      fullscreenGalleryIndex: widget.fullscreenGalleryIndex,
      onFullscreenImageIndexChanged: widget.onFullscreenImageIndexChanged,
      onFullscreenImageMenuRequested: widget.onRequestMenu,
      onFullscreenChanged: (isActive) {
        if (!mounted) {
          widget.onFullscreenChanged?.call(isActive);
          return;
        }
        if (_suppressMenuRequests == isActive) {
          return;
        }
        setState(() {
          _suppressMenuRequests = isActive;
        });
        widget.onFullscreenChanged?.call(isActive);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart:
            widget.onRequestMenu == null
                ? null
                : (details) => _requestMenuIfHit(
                  localPosition: details.localPosition,
                  globalPosition: details.globalPosition,
                ),
        onSecondaryTapDown:
            widget.onRequestMenu == null
                ? null
                : (details) => _requestMenuIfHit(
                  localPosition: details.localPosition,
                  globalPosition: details.globalPosition,
                ),
        child: MaskedImage(url: widget.imageUrl, fit: BoxFit.contain),
      ),
    );
  }
}
