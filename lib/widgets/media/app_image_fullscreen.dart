import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';

const Key kAppImageFullscreenOverlayKey = Key('app-image-fullscreen-overlay');
const Key kAppImageFullscreenCloseButtonKey = Key(
  'app-image-fullscreen-close-button',
);

typedef AppFullscreenBottomDrawerBuilder =
    Widget Function(BuildContext context, ValueChanged<Object?> close);

enum AppImageFullscreenPhase { entering, active, exiting }

class AppFullscreenImageItem {
  const AppFullscreenImageItem({this.url, this.imageProvider})
    : assert(url != null || imageProvider != null);

  final String? url;
  final ImageProvider<Object>? imageProvider;
}

class AppFullscreenZoomController {
  AppFullscreenZoomController({
    required this.sourceRect,
    required this.imageProvider,
    required this.aspectRatio,
    required this.pageController,
    this.galleryItems = const <AppFullscreenImageItem>[],
    this.galleryIndex = 0,
    this.fullscreenImageKey,
    this.onImageIndexChanged,
    this.onImageMenuRequested,
    this.onVisibilityChanged,
  });

  final Rect sourceRect;
  final ImageProvider<Object> imageProvider;
  final double aspectRatio;
  final PageController pageController;
  final List<AppFullscreenImageItem> galleryItems;
  int galleryIndex;
  final Key? fullscreenImageKey;
  final ValueChanged<int>? onImageIndexChanged;
  final void Function(int index, Offset globalPosition)? onImageMenuRequested;
  final ValueChanged<bool>? onVisibilityChanged;
  final Map<int, Offset> activePointers = <int, Offset>{};

  AppImageFullscreenPhase phase = AppImageFullscreenPhase.entering;
  Offset translation = Offset.zero;
  bool isZoomed = false;

  int get itemCount => galleryItems.isEmpty ? 1 : galleryItems.length;

  AppFullscreenImageItem itemAt(int index) {
    if (galleryItems.isEmpty) {
      return AppFullscreenImageItem(imageProvider: imageProvider);
    }

    return galleryItems[index];
  }
}

class _AppFullscreenBottomDrawerSession {
  const _AppFullscreenBottomDrawerSession({
    required this.completer,
    required this.builder,
    required this.heightFactor,
    required this.ignoreTopSafeArea,
    required this.showHandle,
    this.drawerKey,
  });

  final Completer<Object?> completer;
  final AppFullscreenBottomDrawerBuilder builder;
  final Key? drawerKey;
  final double heightFactor;
  final bool ignoreTopSafeArea;
  final bool showHandle;
}

class AppImageFullscreenHost extends StatefulWidget {
  const AppImageFullscreenHost({super.key, required this.child});

  final Widget child;

  static _AppImageFullscreenHostState? _maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<_AppImageFullscreenHostState>();
  }

  static Future<T?>? showBottomDrawer<T>({
    required BuildContext context,
    required AppFullscreenBottomDrawerBuilder builder,
    Key? drawerKey,
    double heightFactor = 0.9,
    bool ignoreTopSafeArea = false,
    bool showHandle = true,
  }) {
    final host = _maybeOf(context);
    if (host == null || !host.isVisible) {
      return null;
    }
    return host._showBottomDrawer<T>(
      builder: builder,
      drawerKey: drawerKey,
      heightFactor: heightFactor,
      ignoreTopSafeArea: ignoreTopSafeArea,
      showHandle: showHandle,
    );
  }

  @override
  State<AppImageFullscreenHost> createState() => _AppImageFullscreenHostState();
}

class _AppImageFullscreenHostState extends State<AppImageFullscreenHost>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _transitionDuration = Duration(milliseconds: 180);
  static const Duration _resetDuration = Duration(milliseconds: 140);
  static const Duration _bottomDrawerDuration = Duration(milliseconds: 180);
  static const double _overlayMaxAlpha = 1.0;
  static const double _tapDismissSlop = 10.0;
  static const double _swipeDismissThreshold = 96.0;

  late final AnimationController _transitionController;
  late final AnimationController _resetController;
  late final AnimationController _bottomDrawerController;
  AppFullscreenZoomController? _session;
  _AppFullscreenBottomDrawerSession? _bottomDrawerSession;
  Animation<Offset>? _resetTranslationAnimation;
  Object? _bottomDrawerResult;
  bool _isClosingBottomDrawer = false;
  int? _tapDismissPointer;
  Offset? _tapDismissStart;
  bool _tapDismissCancelled = false;
  bool _swipeDismissActive = false;
  Timer? _imageMenuLongPressTimer;
  int? _imageMenuLongPressPointer;
  Offset? _imageMenuLongPressStart;
  bool _isSystemUiHidden = false;

  bool get isVisible => _session != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _transitionController =
        AnimationController(vsync: this, duration: _transitionDuration)
          ..addListener(() {
            if (mounted) {
              setState(() {});
            }
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && _session != null) {
              _session!.phase = AppImageFullscreenPhase.active;
              if (mounted) {
                setState(() {});
              }
            }
            if (status == AnimationStatus.dismissed &&
                _session?.phase == AppImageFullscreenPhase.exiting) {
              _finalizeDismiss();
            }
          });
    _resetController =
        AnimationController(vsync: this, duration: _resetDuration)
          ..addListener(_handleResetAnimationTick)
          ..addStatusListener(_handleResetAnimationStatus);
    _bottomDrawerController =
        AnimationController(vsync: this, duration: _bottomDrawerDuration)
          ..addListener(() {
            if (mounted) {
              setState(() {});
            }
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.dismissed && _isClosingBottomDrawer) {
              _completeBottomDrawer(_bottomDrawerResult);
            }
          });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopResetAnimation();
    _cancelImageMenuLongPress();
    _completeBottomDrawer();
    _session?.pageController.dispose();
    unawaited(_restoreSystemUi());
    _bottomDrawerController.dispose();
    _resetController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    if (_session == null) {
      return false;
    }
    dismiss();
    return true;
  }

  bool startSession({
    required Rect sourceRect,
    required ImageProvider<Object> imageProvider,
    required double aspectRatio,
    List<AppFullscreenImageItem> galleryItems =
        const <AppFullscreenImageItem>[],
    int galleryIndex = 0,
    Key? fullscreenImageKey,
    ValueChanged<int>? onImageIndexChanged,
    void Function(int index, Offset globalPosition)? onImageMenuRequested,
    ValueChanged<bool>? onVisibilityChanged,
  }) {
    if (_session != null || aspectRatio <= 0) {
      return false;
    }

    final itemCount = galleryItems.isEmpty ? 1 : galleryItems.length;
    final resolvedIndex = galleryIndex.clamp(0, itemCount - 1).toInt();
    final session = AppFullscreenZoomController(
      sourceRect: sourceRect,
      imageProvider: imageProvider,
      aspectRatio: aspectRatio,
      pageController: PageController(initialPage: resolvedIndex),
      galleryItems: galleryItems,
      galleryIndex: resolvedIndex,
      fullscreenImageKey: fullscreenImageKey,
      onImageIndexChanged: onImageIndexChanged,
      onImageMenuRequested: onImageMenuRequested,
      onVisibilityChanged: onVisibilityChanged,
    );

    _stopResetAnimation();
    _clearTapDismissCandidate();
    _session = session;
    session.onVisibilityChanged?.call(true);
    _transitionController.value = 0;
    _transitionController.forward();
    unawaited(_hideSystemUi());
    if (mounted) {
      setState(() {});
    }
    return true;
  }

  void handlePointerDown(PointerDownEvent event) {
    final session = _session;
    if (session == null) {
      return;
    }
    if (session.phase == AppImageFullscreenPhase.active &&
        session.activePointers.isEmpty) {
      _tapDismissPointer = event.pointer;
      _tapDismissStart = event.position;
      _tapDismissCancelled = false;
    } else {
      _clearTapDismissCandidate();
    }
    _stopResetAnimation();
    session.activePointers[event.pointer] = event.position;
    _startImageMenuLongPress(event);
    if (session.activePointers.length > 1) {
      _tapDismissCancelled = true;
      _cancelImageMenuLongPress();
    }
  }

  void handlePointerMove(PointerMoveEvent event) {
    final session = _session;
    if (session == null || !session.activePointers.containsKey(event.pointer)) {
      return;
    }

    session.activePointers[event.pointer] = event.position;
    _updateImageMenuLongPressCandidate(event.position);
    _updateTapDismissCandidate(event.position);
    if (_updateSwipeDismissCandidate(event.position)) {
      setState(() {});
    }
  }

  void handlePointerEnd(PointerEvent event) {
    final session = _session;
    if (session == null) {
      return;
    }

    session.activePointers.remove(event.pointer);
    if (_imageMenuLongPressPointer == event.pointer) {
      _cancelImageMenuLongPress();
    }
    final shouldDismissFromSwipe = _shouldDismissFromSwipe(event);
    final shouldDismiss = _shouldDismissFromTap(event);
    if (_tapDismissPointer == event.pointer) {
      _clearTapDismissCandidate();
    }
    if (shouldDismissFromSwipe || shouldDismiss) {
      dismiss();
      return;
    }
    if (session.activePointers.isEmpty) {
      _startResetAnimation();
    }
  }

  void dismiss() {
    final session = _session;
    if (session == null || session.phase == AppImageFullscreenPhase.exiting) {
      return;
    }

    _stopResetAnimation();
    _cancelImageMenuLongPress();
    _clearTapDismissCandidate();
    _completeBottomDrawer();
    session.phase = AppImageFullscreenPhase.exiting;
    session.onVisibilityChanged?.call(false);
    _transitionController.reverse(
      from: _transitionController.value.clamp(0.01, 1.0),
    );
    setState(() {});
  }

  Future<void> _hideSystemUi() async {
    if (_isSystemUiHidden) {
      return;
    }
    _isSystemUiHidden = true;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _restoreSystemUi() async {
    if (!_isSystemUiHidden) {
      return;
    }
    _isSystemUiHidden = false;
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  void _finalizeDismiss() {
    _stopResetAnimation();
    _cancelImageMenuLongPress();
    _clearTapDismissCandidate();
    _completeBottomDrawer();
    final session = _session;
    _session = null;
    session?.pageController.dispose();
    unawaited(_restoreSystemUi());
    if (mounted) {
      setState(() {});
    }
  }

  void _updateTapDismissCandidate(Offset position) {
    final start = _tapDismissStart;
    if (_tapDismissPointer == null || start == null) {
      return;
    }
    if ((position - start).distance > _tapDismissSlop) {
      _tapDismissCancelled = true;
    }
  }

  bool _updateSwipeDismissCandidate(Offset position) {
    final session = _session;
    final start = _tapDismissStart;
    if (session == null ||
        session.phase != AppImageFullscreenPhase.active ||
        _tapDismissPointer == null ||
        start == null ||
        session.isZoomed ||
        session.activePointers.length != 1) {
      return false;
    }

    final delta = position - start;
    if (delta.dy <= _tapDismissSlop || delta.dy.abs() <= delta.dx.abs()) {
      _swipeDismissActive = false;
      session.translation = Offset.zero;
      return false;
    }

    _tapDismissCancelled = true;
    _swipeDismissActive = true;
    session.translation = Offset(0, delta.dy);
    return true;
  }

  bool _shouldDismissFromTap(PointerEvent event) {
    final session = _session;
    final start = _tapDismissStart;
    if (session == null ||
        event is! PointerUpEvent ||
        session.phase != AppImageFullscreenPhase.active ||
        _tapDismissPointer != event.pointer ||
        start == null ||
        _tapDismissCancelled ||
        session.activePointers.isNotEmpty) {
      return false;
    }
    return (event.position - start).distance <= _tapDismissSlop;
  }

  bool _shouldDismissFromSwipe(PointerEvent event) {
    final session = _session;
    final start = _tapDismissStart;
    if (session == null ||
        event is! PointerUpEvent ||
        session.phase != AppImageFullscreenPhase.active ||
        _tapDismissPointer != event.pointer ||
        start == null ||
        !_swipeDismissActive ||
        session.activePointers.isNotEmpty) {
      return false;
    }

    final delta = event.position - start;
    return delta.dy >= _swipeDismissThreshold &&
        delta.dy.abs() > delta.dx.abs();
  }

  ImageProvider<Object>? _buildFullscreenImageProvider(
    AppFullscreenImageItem item,
  ) {
    if (item.imageProvider != null) {
      return item.imageProvider;
    }

    final resolvedUrl = resolveMediaUrl(
      rawUrl: item.url,
      baseUrl: context.read<SessionStore>().baseUrl,
    );
    if (resolvedUrl == null) {
      return null;
    }
    return CachedNetworkImageProvider(resolvedUrl);
  }

  void _startImageMenuLongPress(PointerDownEvent event) {
    final session = _session;
    if (session == null ||
        session.phase != AppImageFullscreenPhase.active ||
        session.onImageMenuRequested == null ||
        session.activePointers.length != 1) {
      _cancelImageMenuLongPress();
      return;
    }

    _cancelImageMenuLongPress();
    _imageMenuLongPressPointer = event.pointer;
    _imageMenuLongPressStart = event.position;
    _imageMenuLongPressTimer = Timer(kLongPressTimeout, () {
      final currentSession = _session;
      final callback = currentSession?.onImageMenuRequested;
      if (currentSession == null ||
          callback == null ||
          currentSession.phase != AppImageFullscreenPhase.active ||
          !currentSession.activePointers.containsKey(event.pointer)) {
        return;
      }

      _tapDismissCancelled = true;
      _swipeDismissActive = false;
      callback(_resolveCurrentGalleryIndex(currentSession), event.position);
    });
  }

  void _updateImageMenuLongPressCandidate(Offset position) {
    final start = _imageMenuLongPressStart;
    if (_imageMenuLongPressPointer == null || start == null) {
      return;
    }
    if ((position - start).distance > _tapDismissSlop) {
      _cancelImageMenuLongPress();
    }
  }

  void _cancelImageMenuLongPress() {
    _imageMenuLongPressTimer?.cancel();
    _imageMenuLongPressTimer = null;
    _imageMenuLongPressPointer = null;
    _imageMenuLongPressStart = null;
  }

  Future<T?> _showBottomDrawer<T>({
    required AppFullscreenBottomDrawerBuilder builder,
    Key? drawerKey,
    required double heightFactor,
    required bool ignoreTopSafeArea,
    required bool showHandle,
  }) {
    _completeBottomDrawer();
    final completer = Completer<Object?>();
    _bottomDrawerResult = null;
    _isClosingBottomDrawer = false;
    _bottomDrawerSession = _AppFullscreenBottomDrawerSession(
      completer: completer,
      drawerKey: drawerKey,
      heightFactor: heightFactor,
      ignoreTopSafeArea: ignoreTopSafeArea,
      showHandle: showHandle,
      builder: builder,
    );
    if (mounted) {
      setState(() {});
    }
    _bottomDrawerController.forward(from: 0);
    return completer.future.then((value) => value as T?);
  }

  void _closeBottomDrawer([Object? result]) {
    final session = _bottomDrawerSession;
    if (session == null) {
      return;
    }
    if (_isClosingBottomDrawer) {
      return;
    }
    _bottomDrawerResult = result;
    _isClosingBottomDrawer = true;
    if (_bottomDrawerController.isDismissed) {
      _completeBottomDrawer(result);
      return;
    }
    _bottomDrawerController.reverse();
    if (mounted) {
      setState(() {});
    }
  }

  void _completeBottomDrawer([Object? result]) {
    final session = _bottomDrawerSession;
    if (session == null) {
      return;
    }
    _bottomDrawerSession = null;
    _bottomDrawerResult = null;
    _isClosingBottomDrawer = false;
    _bottomDrawerController.value = 0;
    if (!session.completer.isCompleted) {
      session.completer.complete(result);
    }
    if (mounted) {
      setState(() {});
    }
  }

  int _resolveCurrentGalleryIndex(AppFullscreenZoomController session) {
    final page =
        session.pageController.hasClients ? session.pageController.page : null;
    if (page == null) {
      return session.galleryIndex;
    }

    final index = page.round().clamp(0, session.itemCount - 1);
    session.galleryIndex = index;
    return index;
  }

  void _clearTapDismissCandidate() {
    _tapDismissPointer = null;
    _tapDismissStart = null;
    _tapDismissCancelled = false;
    _swipeDismissActive = false;
  }

  void _handleResetAnimationTick() {
    final session = _session;
    if (session == null) {
      return;
    }

    if (_resetTranslationAnimation != null) {
      session.translation = _resetTranslationAnimation!.value;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _handleResetAnimationStatus(AnimationStatus status) {
    final session = _session;
    if (session == null) {
      return;
    }

    if (status == AnimationStatus.completed) {
      session.translation = Offset.zero;
      _clearResetAnimation();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _startResetAnimation() {
    final session = _session;
    if (session == null) {
      return;
    }

    final currentTranslation = session.translation;
    if (currentTranslation.distanceSquared < 0.001) {
      session.translation = Offset.zero;
      _clearResetAnimation();
      setState(() {});
      return;
    }

    _resetTranslationAnimation = Tween<Offset>(
      begin: currentTranslation,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _resetController, curve: Curves.easeOut));
    _resetController.value = 0;
    _resetController.forward();
  }

  void _stopResetAnimation() {
    if (_resetController.isAnimating) {
      _resetController.stop();
    }
    _clearResetAnimation();
  }

  void _clearResetAnimation() {
    _resetTranslationAnimation = null;
  }

  Rect _resolveContainRect(Size viewport, double aspectRatio) {
    if (aspectRatio <= 0 || viewport.width <= 0 || viewport.height <= 0) {
      return Offset.zero & viewport;
    }

    final viewportAspectRatio = viewport.width / viewport.height;
    late final double width;
    late final double height;
    if (viewportAspectRatio > aspectRatio) {
      height = viewport.height;
      width = height * aspectRatio;
    } else {
      width = viewport.width;
      height = width / aspectRatio;
    }

    return Rect.fromLTWH(
      (viewport.width - width) / 2,
      (viewport.height - height) / 2,
      width,
      height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final overlay =
        session == null
            ? const SizedBox.shrink()
            : _buildOverlay(context, session);

    final bottomDrawer = _buildBottomDrawer(context);

    return PopScope<void>(
      canPop: session == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _bottomDrawerSession != null) {
          _closeBottomDrawer();
          return;
        }
        if (!didPop && session != null) {
          dismiss();
        }
      },
      child: Stack(children: [widget.child, overlay, bottomDrawer]),
    );
  }

  Widget _buildBottomDrawer(BuildContext context) {
    final session = _bottomDrawerSession;
    if (session == null) {
      return const SizedBox.shrink();
    }

    final animationValue = Curves.easeOutCubic.transform(
      _bottomDrawerController.value,
    );

    Widget drawer = Align(
      alignment: Alignment.bottomCenter,
      child: FractionalTranslation(
        translation: Offset(0, 1 - animationValue),
        child: AppBottomDrawerSurface(
          key: session.drawerKey,
          heightFactor: session.heightFactor,
          showHandle: session.showHandle,
          child: session.builder(context, _closeBottomDrawer),
        ),
      ),
    );

    if (session.ignoreTopSafeArea) {
      drawer = SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: true,
        child: drawer,
      );
    }

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeBottomDrawer,
            ),
          ),
          drawer,
        ],
      ),
    );
  }

  Widget _buildOverlay(
    BuildContext context,
    AppFullscreenZoomController session,
  ) {
    final viewport = MediaQuery.sizeOf(context);
    final targetRect = _resolveContainRect(viewport, session.aspectRatio);
    final baseRect =
        Rect.lerp(
          session.sourceRect,
          targetRect,
          Curves.easeOutCubic.transform(_transitionController.value),
        )!;
    final alpha =
        session.phase == AppImageFullscreenPhase.exiting
            ? _transitionController.value
            : Curves.easeOut.transform(_transitionController.value);
    final overlayAlpha = alpha.clamp(0.0, 1.0) * _overlayMaxAlpha;

    return Positioned.fill(
      child: Listener(
        onPointerDown: handlePointerDown,
        onPointerMove: handlePointerMove,
        onPointerUp: handlePointerEnd,
        onPointerCancel: handlePointerEnd,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                key: kAppImageFullscreenOverlayKey,
                color: Colors.black.withValues(alpha: overlayAlpha),
              ),
            ),
            if (session.phase == AppImageFullscreenPhase.active)
              Positioned.fill(
                child: Opacity(
                  opacity: alpha.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: session.translation,
                    child: ClipRect(
                      child: KeyedSubtree(
                        key: session.fullscreenImageKey,
                        child: _buildFullscreenGallery(session),
                      ),
                    ),
                  ),
                ),
              ),
            if (session.phase != AppImageFullscreenPhase.active)
              Positioned.fromRect(
                rect: baseRect,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: alpha.clamp(0.0, 1.0),
                    child: _AppFullscreenImageSurface(
                      imageKey: session.fullscreenImageKey,
                      imageProvider: session.imageProvider,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: context.appSpacing.lg,
              right: context.appSpacing.lg,
              child: Opacity(
                opacity: alpha.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: context.appRadius.pillBorder,
                  ),
                  child: IconButton(
                    key: kAppImageFullscreenCloseButtonKey,
                    onPressed: dismiss,
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.white,
                    tooltip: null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenGallery(AppFullscreenZoomController session) {
    return PhotoViewGallery.builder(
      pageController: session.pageController,
      itemCount: session.itemCount,
      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
      scaleStateChangedCallback: (scaleState) {
        session.isZoomed = scaleState != PhotoViewScaleState.initial;
      },
      onPageChanged: (index) {
        if (session.galleryIndex == index) {
          return;
        }
        session.galleryIndex = index;
        session.isZoomed = false;
        session.onImageIndexChanged?.call(index);
      },
      builder: (context, index) {
        final item = session.itemAt(index);
        final provider = _buildFullscreenImageProvider(item);
        if (provider == null) {
          return PhotoViewGalleryPageOptions.customChild(
            child: const ColoredBox(
              color: Colors.black,
              child: Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white70),
              ),
            ),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4,
          );
        }

        return PhotoViewGalleryPageOptions(
          imageProvider: provider,
          initialScale: PhotoViewComputedScale.contained,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
          basePosition: Alignment.center,
          filterQuality: FilterQuality.medium,
          errorBuilder:
              (context, error, stackTrace) => const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                  ),
                ),
              ),
        );
      },
    );
  }
}

class _AppFullscreenImageSurface extends StatelessWidget {
  const _AppFullscreenImageSurface({
    this.imageKey,
    required this.imageProvider,
  });

  final Key? imageKey;
  final ImageProvider<Object> imageProvider;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Image(
        key: imageKey,
        image: imageProvider,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white70),
            ),
          );
        },
      ),
    );
  }
}

class AppPinchToFullscreenImage extends StatefulWidget {
  const AppPinchToFullscreenImage({
    super.key,
    required this.child,
    this.url,
    this.imageProvider,
    this.imageAspectRatio,
    this.fallbackAspectRatio = 1,
    this.fit = BoxFit.contain,
    this.enabled = true,
    this.fullscreenImageKey,
    this.fullscreenGalleryItems = const <AppFullscreenImageItem>[],
    this.fullscreenGalleryIndex = 0,
    this.onFullscreenImageIndexChanged,
    this.onFullscreenImageMenuRequested,
    this.onFullscreenChanged,
  }) : assert(url != null || imageProvider != null);

  final Widget child;
  final String? url;
  final ImageProvider<Object>? imageProvider;
  final double? imageAspectRatio;
  final double fallbackAspectRatio;
  final BoxFit fit;
  final bool enabled;
  final Key? fullscreenImageKey;
  final List<AppFullscreenImageItem> fullscreenGalleryItems;
  final int fullscreenGalleryIndex;
  final ValueChanged<int>? onFullscreenImageIndexChanged;
  final void Function(int index, Offset globalPosition)?
  onFullscreenImageMenuRequested;
  final ValueChanged<bool>? onFullscreenChanged;

  @override
  State<AppPinchToFullscreenImage> createState() =>
      _AppPinchToFullscreenImageState();
}

class _AppPinchToFullscreenImageState extends State<AppPinchToFullscreenImage> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  ImageProvider<Object>? _resolvedImageProvider;
  double? _resolvedAspectRatio;
  bool _isFullscreenActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImageProvider();
  }

  @override
  void didUpdateWidget(covariant AppPinchToFullscreenImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.imageProvider != widget.imageProvider ||
        oldWidget.imageAspectRatio != widget.imageAspectRatio) {
      _resolveImageProvider();
    }
  }

  @override
  void dispose() {
    _stopListeningToImageStream();
    super.dispose();
  }

  void _resolveImageProvider() {
    final provider = _buildImageProvider();
    final resolvedAspectRatio = widget.imageAspectRatio;
    if (_resolvedImageProvider == provider &&
        _resolvedAspectRatio == resolvedAspectRatio) {
      return;
    }

    _resolvedImageProvider = provider;
    _resolvedAspectRatio = resolvedAspectRatio;
    if (resolvedAspectRatio != null && resolvedAspectRatio > 0) {
      _stopListeningToImageStream();
      return;
    }
    _listenToImageStream(provider);
  }

  ImageProvider<Object>? _buildImageProvider() {
    if (widget.imageProvider != null) {
      return widget.imageProvider;
    }

    final baseUrl = context.read<SessionStore>().baseUrl;
    final resolvedUrl = resolveMediaUrl(rawUrl: widget.url, baseUrl: baseUrl);
    if (resolvedUrl == null) {
      return null;
    }
    return CachedNetworkImageProvider(resolvedUrl);
  }

  void _listenToImageStream(ImageProvider<Object>? provider) {
    _stopListeningToImageStream();

    if (provider == null) {
      return;
    }

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

      final aspectRatio = width / height;
      if (_resolvedAspectRatio == aspectRatio) {
        return;
      }

      setState(() {
        _resolvedAspectRatio = aspectRatio;
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

  void _handleTapUp(TapUpDetails details) {
    if (!widget.enabled || _isFullscreenActive) {
      return;
    }

    final imageRect = _resolveRenderedImageRect();
    if (imageRect == null || !imageRect.contains(details.globalPosition)) {
      return;
    }

    final host = AppImageFullscreenHost._maybeOf(context);
    final provider = _resolvedImageProvider;
    if (host == null || provider == null) {
      return;
    }

    final started = host.startSession(
      sourceRect: imageRect,
      imageProvider: provider,
      aspectRatio: _effectiveAspectRatio,
      galleryItems: widget.fullscreenGalleryItems,
      galleryIndex: widget.fullscreenGalleryIndex,
      fullscreenImageKey: widget.fullscreenImageKey,
      onImageIndexChanged: widget.onFullscreenImageIndexChanged,
      onImageMenuRequested: widget.onFullscreenImageMenuRequested,
      onVisibilityChanged: _handleFullscreenChanged,
    );
    if (started && mounted) {
      setState(() {
        _isFullscreenActive = true;
      });
    }
  }

  void _handleFullscreenChanged(bool isActive) {
    if (!mounted) {
      widget.onFullscreenChanged?.call(isActive);
      return;
    }

    setState(() {
      _isFullscreenActive = isActive;
    });
    widget.onFullscreenChanged?.call(isActive);
  }

  Rect? _resolveRenderedImageRect() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    final localRect = _resolveImageLocalRect(renderObject.size);
    final origin = renderObject.localToGlobal(Offset.zero);
    return localRect.shift(origin);
  }

  Rect _resolveImageLocalRect(Size size) {
    final aspectRatio = _effectiveAspectRatio;
    if (size.width <= 0 || size.height <= 0 || aspectRatio <= 0) {
      return Offset.zero & size;
    }

    switch (widget.fit) {
      case BoxFit.cover:
      case BoxFit.fill:
      case BoxFit.fitWidth:
      case BoxFit.fitHeight:
      case BoxFit.none:
      case BoxFit.scaleDown:
        return Offset.zero & size;
      case BoxFit.contain:
        final viewportAspectRatio = size.width / size.height;
        late final double width;
        late final double height;
        if (viewportAspectRatio > aspectRatio) {
          height = size.height;
          width = height * aspectRatio;
        } else {
          width = size.width;
          height = width / aspectRatio;
        }
        return Rect.fromLTWH(
          (size.width - width) / 2,
          (size.height - height) / 2,
          width,
          height,
        );
    }
  }

  double get _effectiveAspectRatio {
    final aspectRatio = _resolvedAspectRatio;
    if (aspectRatio != null && aspectRatio > 0) {
      return aspectRatio;
    }
    return widget.fallbackAspectRatio > 0 ? widget.fallbackAspectRatio : 1;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: _handleTapUp,
      child: widget.child,
    );
  }
}
