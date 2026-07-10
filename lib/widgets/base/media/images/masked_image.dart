import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/config/app_image_config.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/theme.dart';

/// 通用远程图入口（列表/卡片封面/头像等）。
///
/// 内部维护 ImageProvider 缓存以对抗高频 parent rebuild：
/// - 直接把 `CachedNetworkImageProvider` + 派生的 `ResizeImage` 挂在 State 上，
///   只有 `url` 或 decodeHint 变化时才重建；
/// - 由 `Image` widget 消费稳定的 provider，避免走过去 `CachedNetworkImage → OctoImage`
///   路径下每次 build 因 `ResizeImage` 无 `==` 覆盖被视为"新图"导致 Image element
///   被 `ValueKey(image)` 强制替换、fade 动画 250ms 重放的闪烁问题。
///
/// 兼容原 API：`visibleWidthFactor` + `visibleAlignment` 分支保留（hot_reviews 卡片依赖）。
/// 新增可选 `alignment`——直接传给 `Image.alignment`，用于横图裁竖封面时需要 topCenter 等场景。
class MaskedImage extends StatefulWidget {
  const MaskedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
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

  /// 图片在容器内的对齐方式（与 `BoxFit.cover` 组合决定裁哪一侧）。
  /// 竖封面套横框场景常传 `Alignment.topCenter` 露出海报上半部（番号+人脸）。
  final AlignmentGeometry alignment;

  final double? visibleWidthFactor;
  final AlignmentGeometry visibleAlignment;
  final int? memCacheWidth;
  final int? memCacheHeight;

  @override
  State<MaskedImage> createState() => _MaskedImageState();
}

class _MaskedImageState extends State<MaskedImage> {
  /// baseUrl 拼过后的完整 URL；null 表示解析不出可用地址（会走 placeholder）。
  String? _resolvedUrl;

  /// 未包 ResizeImage 的裸 network provider。同一 URL 复用同一实例，
  /// 保持 identity 稳定 → didUpdateWidget 里 `oldWidget.image != widget.image` 走"未变"分支。
  ImageProvider<Object>? _baseProvider;

  /// 应用了 memCacheWidth/Height 的 ResizeImage 包装；若两者都为空则退化为 base。
  ImageProvider<Object>? _wrappedProvider;
  int? _lastDecodeWidth;
  int? _lastDecodeHeight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // baseUrl 可能来自 SessionStore（登录切后端时会变），依赖变更时兜底重算。
    _rebuildBaseProviderIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MaskedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _rebuildBaseProviderIfNeeded();
    }
  }

  void _rebuildBaseProviderIfNeeded() {
    final baseUrl = context.read<SessionStore>().baseUrl;
    final resolvedUrl = resolveMediaUrl(rawUrl: widget.url, baseUrl: baseUrl);
    if (resolvedUrl == _resolvedUrl) {
      return;
    }
    _resolvedUrl = resolvedUrl;
    _baseProvider =
        resolvedUrl == null ? null : CachedNetworkImageProvider(resolvedUrl);
    // decodeHint 关联的派生 provider 需要跟着重算。
    _wrappedProvider = null;
    _lastDecodeWidth = null;
    _lastDecodeHeight = null;
  }

  /// 按当前布局的 decodeHint 派生（或复用）ResizeImage 包装。
  /// 关键：同一 (baseProvider, w, h) 组合始终返回**同一 ImageProvider 实例**，
  /// 让 Image widget 的 didUpdateWidget 判定"图片未变"，跳过 element 重建。
  ImageProvider<Object>? _ensureWrappedProvider(int? width, int? height) {
    if (_baseProvider == null) {
      return null;
    }
    if (_wrappedProvider != null &&
        _lastDecodeWidth == width &&
        _lastDecodeHeight == height) {
      return _wrappedProvider;
    }
    _lastDecodeWidth = width;
    _lastDecodeHeight = height;
    if (width == null && height == null) {
      _wrappedProvider = _baseProvider;
    } else {
      _wrappedProvider = ResizeImage(
        _baseProvider!,
        width: width,
        height: height,
        allowUpscaling: false,
      );
    }
    return _wrappedProvider;
  }

  @override
  Widget build(BuildContext context) {
    if (_baseProvider == null) {
      return const _MaskedImagePlaceholder(icon: Icons.image_outlined);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final decodeHint = _resolveDecodeHint(context, constraints);
        final provider = _ensureWrappedProvider(
          widget.memCacheWidth ?? decodeHint.width,
          widget.memCacheHeight ?? decodeHint.height,
        );
        if (provider == null) {
          return const _MaskedImagePlaceholder(icon: Icons.image_outlined);
        }

        Widget imageContent = Image(
          image: provider,
          fit: widget.fit,
          alignment: widget.alignment,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) {
              return child;
            }
            return const _MaskedImagePlaceholder(icon: Icons.image_outlined);
          },
          errorBuilder: (context, error, stackTrace) {
            return const _MaskedImagePlaceholder(
              icon: Icons.broken_image_outlined,
            );
          },
        );

        if (AppImageConfig.enableBlur && AppImageConfig.blurSigma > 0) {
          imageContent = ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: AppImageConfig.blurSigma,
              sigmaY: AppImageConfig.blurSigma,
            ),
            child: imageContent,
          );
        }

        if (widget.visibleWidthFactor == null) {
          return imageContent;
        }

        if (!constraints.hasBoundedWidth || !constraints.maxWidth.isFinite) {
          return imageContent;
        }

        final croppedWidth = constraints.maxWidth / widget.visibleWidthFactor!;
        final croppedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : null;

        return ClipRect(
          child: OverflowBox(
            alignment: widget.visibleAlignment,
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
    final effectiveDpr =
        dpr.clamp(1.0, MaskedImage._decodeDevicePixelRatioCap) as double;

    int? cacheWidth;
    if (constraints.hasBoundedWidth &&
        constraints.maxWidth.isFinite &&
        constraints.maxWidth > 0) {
      final factor = widget.visibleWidthFactor;
      final widthMultiplier =
          (factor != null && factor > 0 && factor <= 1) ? 1 / factor : 1.0;
      cacheWidth =
          ((constraints.maxWidth * widthMultiplier * effectiveDpr).round())
                  .clamp(1, MaskedImage._decodeSizeUpperBound)
              as int;
    }

    int? cacheHeight;
    if (constraints.hasBoundedHeight &&
        constraints.maxHeight.isFinite &&
        constraints.maxHeight > 0) {
      cacheHeight =
          ((constraints.maxHeight * effectiveDpr).round()).clamp(
                1,
                MaskedImage._decodeSizeUpperBound,
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
