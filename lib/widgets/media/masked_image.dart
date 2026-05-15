import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/config/app_image_config.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/theme.dart';

class MaskedImage extends StatelessWidget {
  const MaskedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.visibleWidthFactor,
    this.visibleAlignment = Alignment.center,
    this.memCacheWidth,
    this.memCacheHeight,
  }) : assert(
         visibleWidthFactor == null ||
             (visibleWidthFactor > 0 && visibleWidthFactor <= 1),
       );

  static const double _decodeDevicePixelRatioCap = 2.0;
  static const int _decodeSizeUpperBound = 1024;

  final String url;
  final BoxFit fit;
  final double? visibleWidthFactor;
  final AlignmentGeometry visibleAlignment;
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  Widget build(BuildContext context) {
    final baseUrl = context.select<SessionStore, String>(
      (store) => store.baseUrl,
    );
    final resolvedUrl = resolveMediaUrl(rawUrl: url, baseUrl: baseUrl);

    if (resolvedUrl == null) {
      return const _MaskedImagePlaceholder(icon: Icons.image_outlined);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final decodeHint = _resolveDecodeHint(context, constraints);

        final image = CachedNetworkImage(
          imageUrl: resolvedUrl,
          cacheManager: AppImageConfig.networkImageCacheManager,
          fit: fit,
          memCacheWidth: memCacheWidth ?? decodeHint.width,
          memCacheHeight: memCacheHeight ?? decodeHint.height,
          fadeInDuration: const Duration(milliseconds: 250),
          fadeOutDuration: const Duration(milliseconds: 150),
          placeholder: (context, url) {
            return const _MaskedImagePlaceholder(icon: Icons.image_outlined);
          },
          errorWidget: (context, url, error) {
            return const _MaskedImagePlaceholder(
              icon: Icons.broken_image_outlined,
            );
          },
        );

        Widget imageContent = image;

        if (AppImageConfig.enableBlur && AppImageConfig.blurSigma > 0) {
          imageContent = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: AppImageConfig.blurSigma,
              sigmaY: AppImageConfig.blurSigma,
            ),
            child: imageContent,
          );
        }

        if (visibleWidthFactor == null) {
          return imageContent;
        }

        if (!constraints.hasBoundedWidth || !constraints.maxWidth.isFinite) {
          return imageContent;
        }

        final croppedWidth = constraints.maxWidth / visibleWidthFactor!;
        final croppedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : null;

        return ClipRect(
          child: OverflowBox(
            alignment: visibleAlignment,
            minWidth: croppedWidth,
            maxWidth: croppedWidth,
            minHeight: croppedHeight,
            maxHeight: croppedHeight,
            child: SizedBox(
              width: croppedWidth,
              height: croppedHeight,
              child: imageContent,
            ),
          ),
        );
      },
    );
  }

  ({int? width, int? height}) _resolveDecodeHint(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final effectiveDpr = dpr.clamp(1.0, _decodeDevicePixelRatioCap) as double;

    int? cacheWidth;
    if (constraints.hasBoundedWidth &&
        constraints.maxWidth.isFinite &&
        constraints.maxWidth > 0) {
      final factor = visibleWidthFactor;
      final widthMultiplier =
          (factor != null && factor > 0 && factor <= 1) ? 1 / factor : 1.0;
      cacheWidth =
          ((constraints.maxWidth * widthMultiplier * effectiveDpr).round())
                  .clamp(1, _decodeSizeUpperBound)
              as int;
    }

    int? cacheHeight;
    if (constraints.hasBoundedHeight &&
        constraints.maxHeight.isFinite &&
        constraints.maxHeight > 0) {
      cacheHeight =
          ((constraints.maxHeight * effectiveDpr).round()).clamp(
                1,
                _decodeSizeUpperBound,
              )
              as int;
    }

    if (cacheWidth != null && cacheHeight != null) {
      return (width: cacheWidth, height: null);
    }

    return (width: cacheWidth, height: cacheHeight);
  }
}

class _MaskedImagePlaceholder extends StatelessWidget {
  const _MaskedImagePlaceholder({required this.icon});

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
          color: context.appTextPalette.muted,
        ),
      ),
    );
  }
}
