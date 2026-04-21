import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/theme.dart';

const Key kAppImageFullscreenOverlayKey = Key('app-image-fullscreen-overlay');
const Key kAppImageFullscreenCloseButtonKey = Key(
  'app-image-fullscreen-close-button',
);

enum _AppImageFullscreenPhase { entering, active, exiting }

class AppFullscreenZoomController {
  AppFullscreenZoomController({
    required this.sourceRect,
    required this.imageProvider,
    required this.aspectRatio,
    required Map<int, Offset> initialPointers,
    this.fullscreenImageKey,
    this.onVisibilityChanged,
  }) : activePointers = Map<int, Offset>.from(initialPointers);

  final Rect sourceRect;
  final ImageProvider<Object> imageProvider;
  final double aspectRatio;
  final Key? fullscreenImageKey;
  final ValueChanged<bool>? onVisibilityChanged;
  final Map<int, Offset> activePointers;

  _AppImageFullscreenPhase phase = _AppImageFullscreenPhase.entering;
  double scale = 1.0;
  Offset translation = Offset.zero;
  Offset _baselineFocal = Offset.zero;
  Offset _baselineTranslation = Offset.zero;
  double _baselineScale = 1.0;
  double _baselineDistance = 1.0;

  void resetBaseline() {
    if (activePointers.isEmpty) {
      _baselineFocal = Offset.zero;
      _baselineTranslation = translation;
      _baselineScale = scale;
      _baselineDistance = 1.0;
      return;
    }

    final points = _sortedPoints();
    _baselineFocal = _resolveFocalPoint(points);
    _baselineTranslation = translation;
    _baselineScale = scale;
    _baselineDistance =
        points.length >= 2 ? _resolvePointerDistance(points) : 1.0;
  }

  List<Offset> _sortedPoints() {
    final entries =
        activePointers.entries.toList()
          ..sort((left, right) => left.key.compareTo(right.key));
    return entries.map((entry) => entry.value).toList(growable: false);
  }

  static Offset _resolveFocalPoint(List<Offset> points) {
    if (points.isEmpty) {
      return Offset.zero;
    }
    if (points.length == 1) {
      return points.first;
    }
    return Offset(
      (points[0].dx + points[1].dx) / 2,
      (points[0].dy + points[1].dy) / 2,
    );
  }

  static double _resolvePointerDistance(List<Offset> points) {
    if (points.length < 2) {
      return 1.0;
    }
    return (points[1] - points[0]).distance.clamp(1.0, double.infinity);
  }
}

class AppImageFullscreenHost extends StatefulWidget {
  const AppImageFullscreenHost({super.key, required this.child});

  final Widget child;

  static _AppImageFullscreenHostState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<_AppImageFullscreenHostState>();
  }

  @override
  State<AppImageFullscreenHost> createState() => _AppImageFullscreenHostState();
}

class _AppImageFullscreenHostState extends State<AppImageFullscreenHost>
    with SingleTickerProviderStateMixin {
  static const Duration _transitionDuration = Duration(milliseconds: 180);
  static const double _minInteractiveScale = 0.8;
  static const double _maxInteractiveScale = 4.0;

  late final AnimationController _transitionController;
  AppFullscreenZoomController? _session;
  bool _isSystemUiHidden = false;

  bool get isVisible => _session != null;

  @override
  void initState() {
    super.initState();
    _transitionController =
        AnimationController(vsync: this, duration: _transitionDuration)
          ..addListener(() {
            if (mounted) {
              setState(() {});
            }
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && _session != null) {
              _session!.phase = _AppImageFullscreenPhase.active;
            }
            if (status == AnimationStatus.dismissed &&
                _session?.phase == _AppImageFullscreenPhase.exiting) {
              _finalizeDismiss();
            }
          });
  }

  @override
  void dispose() {
    unawaited(_restoreSystemUi());
    _transitionController.dispose();
    super.dispose();
  }

  bool startSession({
    required Rect sourceRect,
    required ImageProvider<Object> imageProvider,
    required double aspectRatio,
    required Map<int, Offset> initialPointers,
    Key? fullscreenImageKey,
    ValueChanged<bool>? onVisibilityChanged,
  }) {
    if (_session != null || aspectRatio <= 0 || initialPointers.length < 2) {
      return false;
    }

    final session = AppFullscreenZoomController(
      sourceRect: sourceRect,
      imageProvider: imageProvider,
      aspectRatio: aspectRatio,
      initialPointers: initialPointers,
      fullscreenImageKey: fullscreenImageKey,
      onVisibilityChanged: onVisibilityChanged,
    )..resetBaseline();

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
    session.activePointers[event.pointer] = event.position;
    session.resetBaseline();
    setState(() {});
  }

  void handlePointerMove(PointerMoveEvent event) {
    final session = _session;
    if (session == null || !session.activePointers.containsKey(event.pointer)) {
      return;
    }

    session.activePointers[event.pointer] = event.position;
    final pointers =
        session.activePointers.entries.toList()
          ..sort((left, right) => left.key.compareTo(right.key));
    final points = pointers.map((entry) => entry.value).toList(growable: false);

    if (points.length >= 2) {
      final focal = AppFullscreenZoomController._resolveFocalPoint(points);
      final distance = AppFullscreenZoomController._resolvePointerDistance(
        points,
      );
      final scaleDelta = distance / session._baselineDistance;
      final nextScale = (session._baselineScale * scaleDelta).clamp(
        _minInteractiveScale,
        _maxInteractiveScale,
      );
      session.scale = nextScale;
      session.translation = _clampTranslation(
        session._baselineTranslation + (focal - session._baselineFocal),
        nextScale,
      );
      setState(() {});
      return;
    }

    if (points.length == 1 && session.scale > 1.0) {
      final focal = points.first;
      session.translation = _clampTranslation(
        session._baselineTranslation + (focal - session._baselineFocal),
        session.scale,
      );
      setState(() {});
    }
  }

  void handlePointerEnd(PointerEvent event) {
    final session = _session;
    if (session == null) {
      return;
    }

    session.activePointers.remove(event.pointer);
    if (session.activePointers.isEmpty) {
      if (session.scale < 1.0) {
        dismiss();
        return;
      }
      session.scale = math.max(1.0, session.scale);
      session.translation = _clampTranslation(
        session.translation,
        session.scale,
      );
      setState(() {});
      return;
    }

    session.resetBaseline();
    setState(() {});
  }

  void dismiss() {
    final session = _session;
    if (session == null || session.phase == _AppImageFullscreenPhase.exiting) {
      return;
    }

    session.phase = _AppImageFullscreenPhase.exiting;
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
    _session = null;
    unawaited(_restoreSystemUi());
    if (mounted) {
      setState(() {});
    }
  }

  Offset _clampTranslation(Offset translation, double scale) {
    final session = _session;
    if (session == null) {
      return translation;
    }

    if (scale <= 1.0) {
      return Offset.zero;
    }

    final viewport = MediaQuery.sizeOf(context);
    final targetRect = _resolveContainRect(viewport, session.aspectRatio);
    final maxDx = math.max(
      0.0,
      (targetRect.width * scale - targetRect.width) / 2,
    );
    final maxDy = math.max(
      0.0,
      (targetRect.height * scale - targetRect.height) / 2,
    );
    return Offset(
      translation.dx.clamp(-maxDx, maxDx),
      translation.dy.clamp(-maxDy, maxDy),
    );
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

    return PopScope<void>(
      canPop: session == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && session != null) {
          dismiss();
        }
      },
      child: Stack(children: [widget.child, overlay]),
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
        session.phase == _AppImageFullscreenPhase.exiting
            ? _transitionController.value
            : Curves.easeOut.transform(_transitionController.value);

    return Positioned.fill(
      child: Listener(
        onPointerDown: handlePointerDown,
        onPointerMove: handlePointerMove,
        onPointerUp: handlePointerEnd,
        onPointerCancel: handlePointerEnd,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            ColoredBox(
              key: kAppImageFullscreenOverlayKey,
              color: Colors.black.withValues(alpha: alpha.clamp(0.0, 1.0)),
            ),
            Positioned.fromRect(
              rect: baseRect,
              child: Transform.translate(
                offset: session.translation,
                child: Transform.scale(
                  scale: session.scale,
                  alignment: Alignment.center,
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
        fit: BoxFit.fill,
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
  final ValueChanged<bool>? onFullscreenChanged;

  @override
  State<AppPinchToFullscreenImage> createState() =>
      _AppPinchToFullscreenImageState();
}

class _AppPinchToFullscreenImageState extends State<AppPinchToFullscreenImage> {
  final Map<int, Offset> _trackedPointers = <int, Offset>{};
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

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled) {
      return;
    }

    final imageRect = _resolveRenderedImageRect();
    if (imageRect == null || !imageRect.contains(event.position)) {
      return;
    }

    _trackedPointers[event.pointer] = event.position;
    if (_trackedPointers.length < 2 || _isFullscreenActive) {
      return;
    }

    final host = AppImageFullscreenHost.maybeOf(context);
    final provider = _resolvedImageProvider;
    if (host == null || provider == null) {
      return;
    }

    final started = host.startSession(
      sourceRect: imageRect,
      imageProvider: provider,
      aspectRatio: _effectiveAspectRatio,
      initialPointers: _trackedPointers,
      fullscreenImageKey: widget.fullscreenImageKey,
      onVisibilityChanged: _handleFullscreenChanged,
    );
    if (started) {
      setState(() {
        _isFullscreenActive = true;
      });
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_trackedPointers.containsKey(event.pointer)) {
      return;
    }
    _trackedPointers[event.pointer] = event.position;
    if (_isFullscreenActive) {
      AppImageFullscreenHost.maybeOf(context)?.handlePointerMove(event);
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    final tracked = _trackedPointers.remove(event.pointer);
    if (tracked == null) {
      return;
    }
    if (_isFullscreenActive) {
      AppImageFullscreenHost.maybeOf(context)?.handlePointerEnd(event);
    }
  }

  void _handleFullscreenChanged(bool isActive) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isFullscreenActive = isActive;
      if (!isActive) {
        _trackedPointers.clear();
      }
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
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: widget.child,
    );
  }
}
