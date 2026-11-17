import 'package:flutter/widgets.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 加载态骨架化的统一入口：把**真实组件树**自动灰化为骨架。
///
/// 使用约定（见 `docs/widgets/feedback.md`）：
/// - loading 分支用占位数据渲染真实卡片 / 网格，外包本组件，骨架即真实布局，
///   不再手写与真实卡平行的骨架组件；
/// - 效果为 [ShimmerEffect]（微光扫过），颜色取主题 `surfaceMuted`（底色）与
///   `surfaceCard`（高光）；系统开启「减少动态效果」时退化为静态
///   [SolidColorEffect]，避免持续动画；
/// - 加载态默认屏蔽子树指针事件（`ignorePointers`），占位渲染期间的交互回调
///   不会触发；
/// - 容器实色绘制（底色 / 边框 / BoxDecoration 阴影，含品牌色、状态色）统一
///   被 `containersColor` 中性化为 `surfaceCard`，骨架内不出现真实颜色；取
///   `surfaceCard` 而非骨块底色 `surfaceMuted`，否则白底容器上的骨块会同色不可见。
///   渐变底与 Material 高度阴影不受影响，需要额外灰化的特殊元素仍可用
///   `Skeleton.shade`；
/// - 共享卡片内部用 [AppSkeletonUnite] 把整卡收敛成一块 shimmer 圆角块，卡内角标 /
///   文字骨块不再单独透出，卡片边框 / 阴影留在 unite 外层；非骨架态原样渲染；
///   合并骨块必须显式传卡片自身圆角，不要直接调用 `Skeleton.unite`；
/// - 加载态对屏幕阅读器隐藏占位内容（占位文案用 `BoneMock`，不是真实数据）。
///
/// [AppSkeletonizer.sliver] 用于把骨架网格直接放进 `CustomScrollView` 的
/// slivers 里；此时不做 [ExcludeSemantics]（sliver 子树无法包盒模型节点）。
class AppSkeletonizer extends StatelessWidget {
  const AppSkeletonizer({super.key, required this.child, this.enabled = true})
    : _sliver = false;

  const AppSkeletonizer.sliver({
    super.key,
    required this.child,
    this.enabled = true,
  }) : _sliver = true;

  /// 真实布局子树；加载分支应传入由占位数据构建的同一份布局。
  final Widget child;

  /// 为 `false` 时原样渲染 [child]，同一棵子树可在加载 / 完成两态间切换。
  final bool enabled;

  final bool _sliver;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final PaintingEffect effect = MediaQuery.disableAnimationsOf(context)
        ? SolidColorEffect(color: colors.surfaceMuted)
        : ShimmerEffect(
            baseColor: colors.surfaceMuted,
            highlightColor: colors.surfaceCard,
          );
    final textBoneBorderRadius = TextBoneBorderRadius(
      context.appRadius.smBorder,
    );
    final effectiveChild = enabled
        ? AppSurfaceStyleScope(style: AppSurfaceStyle.flat, child: child)
        : child;
    if (_sliver) {
      return Skeletonizer.sliver(
        enabled: enabled,
        effect: effect,
        textBoneBorderRadius: textBoneBorderRadius,
        containersColor: colors.surfaceCard,
        child: effectiveChild,
      );
    }
    return Skeletonizer(
      enabled: enabled,
      effect: effect,
      textBoneBorderRadius: textBoneBorderRadius,
      containersColor: colors.surfaceCard,
      child: ExcludeSemantics(excluding: enabled, child: effectiveChild),
    );
  }
}

/// 卡片级骨架合并的统一入口：`Skeleton.unite` 的强制圆角版本。
///
/// 为什么不能直接用 `Skeleton.unite`：skeletonizer 合并骨块时**不保留原布局的
/// 圆角**，而是取合并区内「最大后代」的圆角
/// （`UnitingCanvas.borderRadius`，只有 `drawRRect` / `drawCircle` /
/// `drawParagraph` 会更新它）。卡片里的药丸角标用 `appRadius.pillBorder`
/// （半径 999），一旦它成为最大后代，整张卡会被画成椭圆 / 胶囊——影片卡的热度
/// 胶囊就是这样把 shimmer 亮斑变成椭圆的。
///
/// 这里强制显式声明 [borderRadius]（取卡片外层 `DecoratedBox` / `ClipRRect`
/// 同一个圆角 token），合并骨块便始终与卡片同形，不受卡内元素影响；
/// 未启用骨架化时 `Skeleton.unite` 原样渲染子树，与直接使用无行为差异。
class AppSkeletonUnite extends StatelessWidget {
  const AppSkeletonUnite({
    super.key,
    required this.borderRadius,
    required this.child,
  });

  /// 合并骨块圆角，应与卡片外层装饰 / 裁剪使用同一个 `appRadius` token。
  final BorderRadiusGeometry borderRadius;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Skeleton.unite(borderRadius: borderRadius, child: child);
  }
}
