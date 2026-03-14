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

    final image = CachedNetworkImage(
      imageUrl: resolvedUrl,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: const Duration(milliseconds: 250),
      fadeOutDuration: const Duration(milliseconds: 150),
      placeholder: (context, url) {
        return const _MaskedImagePlaceholder(icon: Icons.image_outlined);
      },
      errorWidget: (context, url, error) {
        return const _MaskedImagePlaceholder(icon: Icons.broken_image_outlined);
      },
    );

    Widget imageContent = image;

    if (AppImageConfig.enableMask) {
      imageContent = ColorFiltered(
        colorFilter: ColorFilter.mode(
          context.appColors.mediaMaskOverlay,
          BlendMode.srcOver,
        ),
        child: image,
      );
    }

    if (visibleWidthFactor == null) {
      return imageContent;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
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
          color: colors.textMuted,
        ),
      ),
    );
  }
}
