import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// 整页底座的共享配方（页面背景引用，底边相接无分割）：
/// 假模糊解码宽 / 底色罩浓度 / 封面羽化宽度。
abstract final class MovieDetailVeil {
  /// 假模糊：解码一张这么宽的小图放大到全屏即糊，替代实时高斯模糊。
  ///
  /// 实时 `ImageFilter.blur` 要一张全屏 saveLayer + 两趟模糊通道（低端机进
  /// 详情页 / 切封面的卡顿来源），模糊边缘还会回透、图层又画出页面矩形
  /// （返回转场的残影来源）；小图放大三样都没有。越小越糊。
  static const int backgroundDecodeWidth = 8;

  /// 底色罩浓度：底座是「模糊封面 + 底色罩」，罩得越实，封面自己的颜色透出越少。
  ///
  /// 浅色主题的白罩过实会把封面两侧留白洗成一块近白平板，清晰封面贴在上面
  /// 边界很明显；降到 0.6 后底色带上封面颜色，封面下方正文仍压在浅底上。
  static const double lightVeilAlpha = 0.6;

  /// 深色主题底座同样偏实（#262626 罩成近黑平板），但彩色一旦透出来，
  /// 浅色正文的对比度掉得比浅色主题更快，只降到 0.7。
  static const double darkVeilAlpha = 0.7;

  /// 封面左右羽化宽度（等于 `spacing.xxl`）：够盖掉硬切，又不吃掉封面内容。
  static const double sideFeather = 32;

  static double veilAlphaFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkVeilAlpha : lightVeilAlpha;
}

/// 影片详情封面 Hero：纯照片，底部化开后把舞台
/// 交给页面背景与照片下方的信息块。这里不画任何文字和按钮，
/// 自身透明（底座就是页面的整页底座，连续一层、无边缘回透）。
///
/// 填充方式由 [heroFit] 决定：桌面保持 [BoxFit.contain] 完整显示不裁切，
/// 移动沉浸全幅传 [BoxFit.cover] 铺满裁切（由 [ClipRect] 裁到框内）。
/// `contain` 下封面居中、两侧留白宽度由封面宽高比决定，照片左右边缘会硬切在
/// 底色上，因此再按封面**实际绘制矩形**做一次左右羽化，和底边化开同一套语言。
class MovieDetailHeroCard extends StatefulWidget {
  const MovieDetailHeroCard({
    super.key,
    required this.height,
    required this.mainImageKey,
    required this.mainImageUrl,
    required this.veilColor,
    this.heroFit = BoxFit.contain,
  });

  /// 实际高度：由调用方算好（桌面按视口、移动窄屏配方），页面用 `Positioned`
  /// 施加紧约束；底部渐隐带与封面绘制矩形都按它计算。
  final double height;
  final String mainImageKey;
  final String? mainImageUrl;

  /// 前景图的填充方式：默认 [BoxFit.contain]，移动端传 [BoxFit.cover]。
  final BoxFit heroFit;

  /// 无封面占位块与图片占位的纯底色：与页面背景回退色一致，不断层。
  /// 桌面传 surfaceElevated、移动传 surfaceCard，因此由调用方决定。
  final Color veilColor;

  /// 底部过渡带占 Hero 高的比例：清晰图在带内化开。
  static const double meltBandFactor = 0.28;

  /// 桌面 Hero 高度 = 视口高 × 该系数（只封顶，不垫底）。
  ///
  /// 调大 → 封面更大、正文更靠下。
  static const double desktopViewportHeightFactor = 0.60;

  @override
  State<MovieDetailHeroCard> createState() => _MovieDetailHeroCardState();
}

class _MovieDetailHeroCardState extends State<MovieDetailHeroCard> {
  /// 解码后的封面尺寸：用来算封面在 hero 里的实际绘制矩形。
  /// 命中内存图片缓存时在 build 期同步取到（[resolveCachedMaskedImageSize]），
  /// 首帧就带上羽化；未命中（首次加载）等 [MaskedImage.onImageSized] 的帧后
  /// 回调补上；都没有时（解码失败 / 拿不到）退化为不羽化，与旧行为一致。
  Size? _imageSize;

  @override
  void didUpdateWidget(MovieDetailHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换图（选其它播放源）后旧尺寸作废，等新图首帧再重算。
    if (oldWidget.mainImageUrl != widget.mainImageUrl) {
      _imageSize = null;
    }
  }

  void _handleImageSized(Size size) {
    if (_imageSize == size) {
      return;
    }
    setState(() => _imageSize = size);
  }

  /// 本次 build 用的封面尺寸：已知直接用；未知时同步查一次内存图片缓存——
  /// 命中就首帧生效（左右羽化不用等到下一帧），未命中返回 null，
  /// 仍由 [MaskedImage.onImageSized] 的帧后回调补。
  Size? _resolveImageSize(BoxConstraints constraints) {
    final known = _imageSize;
    if (known != null) {
      return known;
    }
    // 只有 contain 才按封面实际绘制矩形对齐（cover 铺满、两侧没有留白）。
    final url = widget.mainImageUrl;
    if (widget.heroFit != BoxFit.contain || url == null || url.isEmpty) {
      return null;
    }
    // [MaskedImage] 在 Stack 里 Positioned.fill，拿到的是同一个带宽/带高。
    final size = resolveCachedMaskedImageSize(context, constraints, url: url);
    if (size != null) {
      // build 期写入、不 setState：本帧直接用，也免得帧后回调再触发一次重排。
      _imageSize = size;
    }
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final hasImage =
        widget.mainImageUrl != null && widget.mainImageUrl!.isNotEmpty;
    // 底部化开的羽化宽度：过渡带顶部再往上这么多。
    final meltFeather = spacing.xxxl + spacing.lg;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bandWidth = constraints.maxWidth;
        final imageSize = _resolveImageSize(constraints);
        final height = widget.height;
        final fadeStart =
            (1.0 -
                    MovieDetailHeroCard.meltBandFactor -
                    meltFeather / height)
                .clamp(0.0, 1.0);
        final paintRect = _resolveHeroImagePaintRect(
          bandWidth: bandWidth,
          bandHeight: height,
          imageSize: imageSize,
          fit: widget.heroFit,
        );
        return SizedBox(
          height: height,
          // 前景图裁到框内（cover 时图片会超出框）。
          child: ClipRect(
            child: Stack(
              children: [
                if (hasImage)
                  // 前景图底部过渡带内化开，化开处露出页面背景
                  //（同一张图的模糊，无缝）；左右两侧贴着封面边缘羽化。
                  Positioned.fill(
                    child: _buildHeroImage(
                      fadeStart: fadeStart,
                      paintRect: paintRect,
                      bandWidth: bandWidth,
                    ),
                  )
                else
                  _HeroImageFrame(
                    imageKey: widget.mainImageKey,
                    veilColor: widget.veilColor,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroImage({
    required double fadeStart,
    required Rect? paintRect,
    required double bandWidth,
  }) {
    Widget image = MaskedImage(
      url: widget.mainImageUrl!,
      fit: widget.heroFit,
      alignment: Alignment.center,
      // 占位与无封面块同色（veil 色）：骨架 → 占位 → 图片只剩一次淡入。
      placeholderColor: widget.veilColor,
      onImageSized: _handleImageSized,
    );

    // 左右羽化：只有封面确实比容器窄（contain 两侧有留白）时才加。
    // ShaderMask 一次只能承载一个一维渐变，两向衰减靠两层嵌套相乘。
    final sideStops = paintRect == null
        ? null
        : _resolveSideFeatherStops(
            bandWidth: bandWidth,
            paintRect: paintRect,
            feather: MovieDetailVeil.sideFeather,
          );
    if (sideStops != null) {
      image = ShaderMask(
        key: const Key('movie-detail-hero-side-mask'),
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: sideStops,
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: image,
      );
    }

    return ShaderMask(
      key: const Key('movie-detail-hero-melt-mask'),
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Colors.white, Colors.transparent],
        stops: [fadeStart, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: image,
    );
  }
}

/// 封面在 Hero 里的实际绘制矩形（`contain` 居中、`cover` 铺满）。
///
/// 左右羽化必须贴着封面自己的边缘：Hero 带宽不等于封面宽——`contain` 下封面
/// 居中，两侧留白宽度由封面宽高比决定（竖版封面留白比横版更宽）。
/// 返回 null 表示没有两侧留白（`cover` 铺满、尺寸未知、宽度无界），此时不羽化。
Rect? _resolveHeroImagePaintRect({
  required double bandWidth,
  required double bandHeight,
  required Size? imageSize,
  required BoxFit fit,
}) {
  if (imageSize == null || imageSize.isEmpty) {
    return null;
  }
  if (!bandWidth.isFinite || bandWidth <= 0 || bandHeight <= 0) {
    return null;
  }
  final band = Size(bandWidth, bandHeight);
  final painted = applyBoxFit(fit, imageSize, band).destination;
  if (painted.width >= band.width - 0.5) {
    return null;
  }
  return Alignment.center.inscribe(painted, Offset.zero & band);
}

/// 左右羽化在整条 Hero 带宽上的渐变 stop：封面绘制矩形两端各羽化 [feather]。
///
/// ShaderMask 的 rect 就是 Hero 自身矩形，所以 stop 用带宽归一化；
/// 矩形外没有内容，渐变夹到透明不影响画面。
List<double>? _resolveSideFeatherStops({
  required double bandWidth,
  required Rect paintRect,
  required double feather,
}) {
  if (!bandWidth.isFinite || bandWidth <= 0) {
    return null;
  }
  // 羽化宽度不能超过半张封面，否则两段渐变会交叉。
  final width = feather.clamp(0.0, paintRect.width / 2);
  if (width <= 0.5) {
    return null;
  }
  return [
    paintRect.left / bandWidth,
    (paintRect.left + width) / bandWidth,
    (paintRect.right - width) / bandWidth,
    paintRect.right / bandWidth,
  ];
}

class _HeroImageFrame extends StatelessWidget {
  const _HeroImageFrame({required this.imageKey, required this.veilColor});

  final String imageKey;

  /// 无封面时的纯底色：与页面背景回退色一致，不断层。
  final Color veilColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: Key('movie-detail-main-image-$imageKey'),
      width: double.infinity,
      height: double.infinity,
      child: DecoratedBox(decoration: BoxDecoration(color: veilColor)),
    );
  }
}
