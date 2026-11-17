import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/media/app_image_provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_mask.dart';

/// 通用远程图入口（列表/卡片封面/头像等）。
///
/// 内部维护 ImageProvider 缓存以对抗高频 parent rebuild：
/// - 直接把 `CachedNetworkImageProvider` + 派生的 `ResizeImage` 挂在 State 上，
///   只有 `url` 或 decodeHint 变化时才重建；
/// - 由 `Image` widget 消费稳定的 provider，避免走过去 `CachedNetworkImage → OctoImage`
///   路径下每次 build 因 `ResizeImage` 无 `==` 覆盖被视为"新图"导致 Image element
///   被 `ValueKey(image)` 强制替换、fade 动画 250ms 重放的闪烁问题。
/// - 首帧到达后由 frameBuilder 里的 `AnimatedSwitcher` 完成「占位 → 图片」切换，
///   占位随切换结束自动移除；provider identity 稳定，高频 rebuild 不会重放动画，
///   内存缓存命中（`wasSynchronouslyLoaded`）时直接显示。
/// - URL 切换时暂存上一次解码成功的 provider：新图加载中继续展示旧图，
///   首帧到达后再做一次新旧淡入，避免闪回占位（`Image.gaplessPlayback` 单独
///   加无效：切换时 `_frameNumber` 会被重置，frameBuilder 仍走占位分支）。
/// 新增可选 `alignment`——直接传给 `Image.alignment`，用于横图裁竖封面时需要 topCenter 等场景。
/// 新增可选 `placeholderColor` / `animateReveal`——有连续底色的场景（如影片详情）
/// 让占位与底色同色、背景图关闭淡入，把「骨架 → 占位 → 图片」两次跳变收成一次。
/// 新增可选 `onImageSized`——首帧到达时回调解码尺寸，供调用方按图片实际绘制
/// 矩形做对齐（如影片详情 hero 的左右羽化）；命中内存缓存时可用
/// [resolveCachedMaskedImageSize] 在 build 期同步拿到同一个尺寸，首帧就对齐。
/// 新增可选 `filterQuality`——小图放大的假模糊底座传 `FilterQuality.high`。
/// 开发期 `ENABLE_BLUR=true` 时不解析 provider、不下载图片，直接渲染纯色遮罩。
class MaskedImage extends ConsumerStatefulWidget {
  const MaskedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholderColor,
    this.placeholderBuilder,
    this.errorBuilder,
    this.fadeInDuration = const Duration(milliseconds: 180),
    this.animateReveal = true,
    this.onImageSized,
    this.filterQuality = FilterQuality.low,
  });

  static const int _decodeSizeUpperBound = 1024;

  final String url;
  final BoxFit fit;

  /// 图片在容器内的对齐方式（与 `BoxFit.cover` 组合决定裁哪一侧）。
  /// 竖封面套横框场景常传 `Alignment.topCenter` 露出海报上半部（番号+人脸）。
  final AlignmentGeometry alignment;

  final int? memCacheWidth;
  final int? memCacheHeight;

  /// 首帧到达前占位的纯色：不传时用 `surfaceMuted`。
  /// 有连续底色的场景传入底色（如详情 Hero 传 veil 色、模糊背景传 base 色），
  /// 避免「骨架 → 占位 → 图片」在占位处再跳一次颜色。
  final Color? placeholderColor;

  /// 自定义占位（加载中/无 URL/遮罩模式）。不传时用 [placeholderColor] 或
  /// `surfaceMuted` 的纯色块。
  final WidgetBuilder? placeholderBuilder;

  /// 自定义加载失败 UI。不传时回落到 [placeholderBuilder] 或纯色占位。
  final ImageErrorWidgetBuilder? errorBuilder;

  /// 「占位 → 图片」淡入时长；默认 180ms。
  final Duration fadeInDuration;

  /// 首帧到达后是否做「占位 → 图片」淡入。罩了重 veil 的背景图传 false：
  /// 解码完成后直接显示，避免与前景图两次先后闪烁。
  final bool animateReveal;

  /// 首帧（或换图后新帧）到达时回调解码后的图片尺寸。
  ///
  /// 给需要按图片**实际绘制矩形**对齐的场景用（如影片详情 hero 的左右羽化：
  /// `BoxFit.contain` 下图片居中、两侧留白宽度由图片宽高比决定，
  /// 按整条容器宽度算羽化会落空）。回调统一挪到帧后，调用方可直接 `setState`。
  /// 不传时行为与之前完全一致（不挂监听、不多解码）。
  final ValueChanged<Size>? onImageSized;

  /// 交给 `Image` 的采样质量：默认 `FilterQuality.low`（与 `Image` 默认一致）。
  /// 小图放大的假模糊底座传 `FilterQuality.high`，双线性放大到全屏会有块感。
  final FilterQuality filterQuality;

  @override
  ConsumerState<MaskedImage> createState() => _MaskedImageState();
}

class _MaskedImageState extends ConsumerState<MaskedImage> {
  /// baseUrl 拼过后的完整 URL；null 表示解析不出可用地址（会走 placeholder）。
  String? _resolvedUrl;

  /// 未包 ResizeImage 的裸 network provider。同一 URL 复用同一实例，
  /// 保持 identity 稳定 → didUpdateWidget 里 `oldWidget.image != widget.image` 走"未变"分支。
  ImageProvider<Object>? _baseProvider;

  /// 应用了 memCacheWidth/Height 的 ResizeImage 包装；若两者都为空则退化为 base。
  ImageProvider<Object>? _wrappedProvider;
  int? _lastDecodeWidth;
  int? _lastDecodeHeight;

  /// 最近一次成功解出首帧的派生 provider。URL 切换、新图加载中
  /// （frame == null）时用它继续展示旧图；新图首帧到达后再淡入。
  /// 首进（无旧帧）时为 null，走占位分支，与过去行为一致。
  ImageProvider<Object>? _lastCompletedProvider;

  /// [MaskedImage.onImageSized] 用的旁路监听：挂在同一个 provider 上，
  /// 只为了拿解码尺寸，不额外解码（provider 相同 → 命中同一条缓存）。
  ImageStream? _sizeStream;
  ImageStreamListener? _sizeListener;
  ImageProvider<Object>? _sizeListenerProvider;

  @override
  void dispose() {
    final listener = _sizeListener;
    if (listener != null) {
      _sizeStream?.removeListener(listener);
    }
    super.dispose();
  }

  /// provider 变化时重挂尺寸监听。
  void _syncSizeListener(ImageProvider<Object> provider) {
    if (widget.onImageSized == null ||
        identical(provider, _sizeListenerProvider)) {
      return;
    }
    final listener = _sizeListener ??= ImageStreamListener(
      _handleImageSized,
      // 尺寸回调是尽力而为：加载失败交给 Image 自己的 errorBuilder。
      onError: (_, _) {},
    );
    _sizeStream?.removeListener(listener);
    _sizeListenerProvider = provider;
    _sizeStream = provider.resolve(createLocalImageConfiguration(context))
      ..addListener(listener);
  }

  void _handleImageSized(ImageInfo info, bool synchronousCall) {
    final onImageSized = widget.onImageSized;
    if (onImageSized == null) {
      return;
    }
    final size = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    // 缓存命中时这里可能在 build 期间同步触发，统一挪到帧后，
    // 调用方才能安全 setState。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onImageSized?.call(size);
    });
  }

  void _rebuildBaseProviderIfNeeded(String baseUrl) {
    final resolvedUrl = resolveMediaUrl(rawUrl: widget.url, baseUrl: baseUrl);
    if (resolvedUrl == _resolvedUrl) {
      return;
    }
    _resolvedUrl = resolvedUrl;
    _baseProvider = resolvedUrl == null
        ? null
        : buildRemoteImageProvider(resolvedUrl);
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
    _wrappedProvider = _wrapDecodeHint(_baseProvider!, width, height);
    return _wrappedProvider;
  }

  @override
  Widget build(BuildContext context) {
    if (AppImageMask.enabled) {
      return _buildPlaceholder(
        context,
        defaultColor: AppImageMask.colorFor(
          context,
          AppImageMask.seedForUrl(widget.url),
        ),
      );
    }

    // baseUrl 细粒度订阅（登录切后端时精准重建）；url/decodeHint 的缓存策略不变。
    _rebuildBaseProviderIfNeeded(ref.watch(baseUrlProvider));
    if (_baseProvider == null) {
      return _buildPlaceholder(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final decodeHint = _resolveDecodeHint(context, constraints);
        final provider = _ensureWrappedProvider(
          widget.memCacheWidth ?? decodeHint.width,
          widget.memCacheHeight ?? decodeHint.height,
        );
        if (provider == null) {
          return _buildPlaceholder(context);
        }
        _syncSizeListener(provider);

        return Image(
          image: provider,
          fit: widget.fit,
          alignment: widget.alignment,
          filterQuality: widget.filterQuality,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) {
              _lastCompletedProvider = provider;
              return child;
            }
            if (frame != null) {
              _lastCompletedProvider = provider;
              final current = KeyedSubtree(
                key: const ValueKey<String>('image'),
                child: child,
              );
              if (!widget.animateReveal) {
                return current;
              }
              return _buildReveal(child: current);
            }
            // 加载中：有旧帧时继续展示旧图（静态，不播动画），没有才走占位。
            // 新图首帧到达后，AnimatedSwitcher 会以 key 区分做一次旧图 → 新图淡入。
            final previous = _lastCompletedProvider;
            final Widget loadingChild;
            if (previous != null && previous != provider) {
              loadingChild = KeyedSubtree(
                key: const ValueKey<String>('previous-image'),
                child: Image(
                  image: previous,
                  fit: widget.fit,
                  alignment: widget.alignment,
                  filterQuality: widget.filterQuality,
                  gaplessPlayback: true,
                  errorBuilder: _buildError,
                ),
              );
            } else {
              loadingChild = KeyedSubtree(
                key: const ValueKey<String>('placeholder'),
                child: _buildPlaceholder(context),
              );
            }
            if (!widget.animateReveal) {
              return loadingChild;
            }
            return _buildReveal(child: loadingChild);
          },
          errorBuilder: _buildError,
        );
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context, {Color? defaultColor}) {
    return widget.placeholderBuilder?.call(context) ??
        _MaskedImagePlaceholder(color: widget.placeholderColor ?? defaultColor);
  }

  Widget _buildError(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return widget.errorBuilder?.call(context, error, stackTrace) ??
        _buildPlaceholder(context);
  }

  /// 「占位 → 图片」的淡入容器。child 必须带不同 key（placeholder /
  /// previous-image / image）：AnimatedSwitcher 只在 key 变化时保留旧 child
  /// 做淡出，否则占位会瞬间消失。
  /// AnimatedSwitcher 默认 layoutBuilder 的 Stack 会给子级 loose
  /// constraints，`Image` 便退回按自身比例布局——`cover` 实际变成
  /// 「contain + 留白」。有界约束下改用 StackFit.expand，让封面真正
  /// 铺满并按 `fit` 裁切。
  Widget _buildReveal({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canFill =
            constraints.hasBoundedWidth && constraints.hasBoundedHeight;
        return AnimatedSwitcher(
          duration: widget.fadeInDuration,
          switchInCurve: Curves.easeOut,
          layoutBuilder: canFill
              ? _fillAnimatedSwitcherLayout
              : AnimatedSwitcher.defaultLayoutBuilder,
          child: child,
        );
      },
    );
  }
}

/// 同步取「已解码尺寸」：命中内存图片缓存时立即可用（**不触发新解码**），
/// 未命中（首次加载 / 已被淘汰 / URL 解析不出）返回 null。
///
/// 给必须**首帧**就按图片实际绘制矩形对齐的调用方用（影片详情 hero 的左右羽化）：
/// 在 build 期调用它，首帧的绘制矩形就已经正确；否则只能等
/// [MaskedImage.onImageSized] 的帧后回调，羽化会晚一帧才出现，并多触发一次重排。
///
/// [constraints] 必须与 [MaskedImage] 实际拿到的约束一致（同样的约束 → 同一个
/// 解码尺寸提示 → 同一条缓存）；[memCacheWidth] / [memCacheHeight] 也要与
/// 传给 [MaskedImage] 的值一致才可能命中。未命中时调用方按「尺寸未知」处理即可。
Size? resolveCachedMaskedImageSize(
  BuildContext context,
  BoxConstraints constraints, {
  required String url,
  int? memCacheWidth,
  int? memCacheHeight,
}) {
  if (AppImageMask.enabled) {
    return null;
  }

  final baseUrl = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(baseUrlProvider);
  final resolvedUrl = resolveMediaUrl(rawUrl: url, baseUrl: baseUrl);
  if (resolvedUrl == null) {
    return null;
  }
  final decodeHint = _resolveDecodeHint(context, constraints);
  final provider = _wrapDecodeHint(
    buildRemoteImageProvider(resolvedUrl),
    memCacheWidth ?? decodeHint.width,
    memCacheHeight ?? decodeHint.height,
  );

  Size? size;
  final listener = ImageStreamListener(
    (info, _) =>
        size = Size(info.image.width.toDouble(), info.image.height.toDouble()),
    // 尺寸探测是尽力而为：失败按未命中处理，交给 Image 自己的 errorBuilder。
    onError: (_, _) {},
  );
  // 命中缓存时 addListener 会同步派发首帧，这里就已经拿到尺寸；
  // 未命中则立刻摘掉监听，不干扰同一条 pending 加载（缓存自己持有监听）。
  final stream = provider.resolve(createLocalImageConfiguration(context));
  stream.addListener(listener);
  stream.removeListener(listener);
  return size;
}

/// [MaskedImage] 的布局 → 解码尺寸提示：宽度有界按宽度、否则按高度，上限
/// [MaskedImage._decodeSizeUpperBound]；两者都有界时只按宽度（保持宽高比）。
({int? width, int? height}) _resolveDecodeHint(
  BuildContext context,
  BoxConstraints constraints,
) {
  final dpr = MediaQuery.devicePixelRatioOf(context);

  int? cacheWidth;
  if (constraints.hasBoundedWidth &&
      constraints.maxWidth.isFinite &&
      constraints.maxWidth > 0) {
    final rawWidth = (constraints.maxWidth * dpr).round();
    cacheWidth = rawWidth.clamp(1, MaskedImage._decodeSizeUpperBound);
  }

  int? cacheHeight;
  if (constraints.hasBoundedHeight &&
      constraints.maxHeight.isFinite &&
      constraints.maxHeight > 0) {
    final rawHeight = (constraints.maxHeight * dpr).round();
    cacheHeight = rawHeight.clamp(1, MaskedImage._decodeSizeUpperBound);
  }

  if (cacheWidth != null && cacheHeight != null) {
    return (width: cacheWidth, height: null);
  }

  return (width: cacheWidth, height: cacheHeight);
}

/// 按解码尺寸提示包一层 [ResizeImage]（与 [MaskedImage] 内部同规则）；
/// 两者都为空时直接用 base provider。
ImageProvider<Object> _wrapDecodeHint(
  ImageProvider<Object> base,
  int? width,
  int? height,
) {
  if (width == null && height == null) {
    return base;
  }
  return ResizeImage(base, width: width, height: height, allowUpscaling: false);
}

/// [AnimatedSwitcher] 在有界约束下的 layoutBuilder：用 `StackFit.expand` 让新旧
/// child 都铺满，避免默认 Stack 的 loose 约束把 `cover` 退化成「contain + 留白」。
Widget _fillAnimatedSwitcherLayout(
  Widget? currentChild,
  List<Widget> previousChildren,
) => Stack(
  fit: StackFit.expand,
  children: <Widget>[...previousChildren, ?currentChild],
);

/// 首帧 / 缺图 / 加载失败的统一占位：默认 muted 纯色块，不带居中图标
/// （纯图片卡的占位与骨架统一为纯块，图标会被 skeletonizer 画成实心方块）。
/// 有连续底色的场景可传 `color` 与底色对齐，避免占位处再跳一次颜色。
class _MaskedImagePlaceholder extends StatelessWidget {
  const _MaskedImagePlaceholder({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color ?? context.appColors.surfaceMuted,
      child: const Center(),
    );
  }
}
