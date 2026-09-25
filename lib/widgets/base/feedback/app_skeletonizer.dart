import 'package:flutter/widgets.dart';
import 'package:sakuramedia/theme.dart';
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
///   不会触发；品牌底色元素用 `Skeleton.shade` 随骨架灰化；
/// - 共享卡片内部用 `Skeleton.unite` 把整卡收敛成一块 shimmer 圆角块，卡内角标 /
///   文字骨块不再单独透出，卡片边框 / 阴影留在 unite 外层；非骨架态原样渲染；
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
    if (_sliver) {
      return Skeletonizer.sliver(
        enabled: enabled,
        effect: effect,
        textBoneBorderRadius: textBoneBorderRadius,
        child: child,
      );
    }
    return Skeletonizer(
      enabled: enabled,
      effect: effect,
      textBoneBorderRadius: textBoneBorderRadius,
      child: ExcludeSemantics(excluding: enabled, child: child),
    );
  }
}
