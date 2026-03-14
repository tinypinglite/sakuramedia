import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/config/app_image_config.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/theme.dart';

class MoviePlotThumbnail extends StatefulWidget {
  const MoviePlotThumbnail({
    super.key,
    required this.maxHeight,
    this.url,
    this.imageProvider,
    this.fit = BoxFit.cover,
    this.fallbackAspectRatio = 1,
    this.borderRadius,
  }) : assert(url != null || imageProvider != null);

  final String? url;
  final ImageProvider<Object>? imageProvider;
  final double maxHeight;
  final BoxFit fit;
  final double fallbackAspectRatio;
  final BorderRadius? borderRadius;

  @override
  State<MoviePlotThumbnail> createState() => _MoviePlotThumbnailState();
}

class _MoviePlotThumbnailState extends State<MoviePlotThumbnail> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  ImageProvider<Object>? _resolvedImageProvider;
  double? _aspectRatio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImageProvider();
  }

  @override
  void didUpdateWidget(covariant MoviePlotThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.imageProvider != widget.imageProvider) {
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
    if (_resolvedImageProvider == provider) {
      return;
    }

    _resolvedImageProvider = provider;
    _aspectRatio = null;
    _listenToImageStream(provider);
  }

  ImageProvider<Object>? _buildImageProvider() {
    if (widget.imageProvider != null) {
      return widget.imageProvider;
    }

    final baseUrl = context.read<SessionStore>().baseUrl;
    final resolvedUrl = resolveMediaUrl(
      rawUrl: widget.url ?? '',
      baseUrl: baseUrl,
    );
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

      setState(() {
        _aspectRatio = width / height;
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final radius = widget.borderRadius ?? BorderRadius.zero;

    if (_resolvedImageProvider == null) {
      return SizedBox(
        height: widget.maxHeight,
        child: ClipRRect(
          borderRadius: radius,
          child: AspectRatio(
            aspectRatio: widget.fallbackAspectRatio,
            child: const _PlotThumbnailPlaceholder(icon: Icons.image_outlined),
          ),
        ),
      );
    }

    Widget image = Image(
      image: _resolvedImageProvider!,
      fit: widget.fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return const _PlotThumbnailPlaceholder(icon: Icons.image_outlined);
      },
      errorBuilder: (context, error, stackTrace) {
        return const _PlotThumbnailPlaceholder(
          icon: Icons.broken_image_outlined,
        );
      },
    );

    if (AppImageConfig.enableMask) {
      image = ColorFiltered(
        colorFilter: ColorFilter.mode(
          colors.mediaMaskOverlay,
          BlendMode.srcOver,
        ),
        child: image,
      );
    }

    return SizedBox(
      height: widget.maxHeight,
      child: ClipRRect(
        borderRadius: radius,
        child: AspectRatio(
          aspectRatio: _aspectRatio ?? widget.fallbackAspectRatio,
          child: image,
        ),
      ),
    );
  }
}

class _PlotThumbnailPlaceholder extends StatelessWidget {
  const _PlotThumbnailPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surfaceMuted),
      child: Center(
        child: Icon(
          icon,
          size: componentTokens.iconSize3xl,
          color: colors.textMuted,
        ),
      ),
    );
  }
}
