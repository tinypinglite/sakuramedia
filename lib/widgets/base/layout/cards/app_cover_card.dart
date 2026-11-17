import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/app_cover_hover_info.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_check_badge.dart';

/// 全站「整卡即封面」卡片的统一壳：卡片装饰 + 封面区 + 常驻角标。
///
/// 外观固定为设计语言基线，调用方不要再手写这几层：
/// `surfaceCard` 底、`lg` 圆角、常驻 1px `borderSubtle` 边框（选中换 2px
/// `selectionBorder`）、`ClipRRect` 圆角裁剪、
/// `AppSkeletonUnite` 强制同圆角合并骨块（防卡内药丸角标把整卡画成椭圆）。
///
/// 封面区组装规则：
/// - [infoBuilder] 非空时包 [AppCoverHoverInfo]（触摸端无 hover 保持收起）；
///   [collapsedOverlay] 透传为其收起态前景层；
/// - [coverAspectRatio] 非空时封面区套 [AspectRatio]，为空时直接铺满父约束
///   （网格 cell / 瀑布流 tile 已定比例，或 `expandToParent` 场景）；
/// - [overlays] / [overlaysBuilder] 叠在封面区上的常驻角标，自行用 `Positioned`
///   定位（两者都会被包进同一层 `Stack`）；需要按卡片实际宽度排版时用
///   [overlaysBuilder]（如影片卡热度折行）；
/// - [selectionMode] 时由壳统一叠左上角勾选徽标，调用方不要再画；
/// - [footer] 是封面区下方的常驻内容（如合集卡的标题行）。
///
/// 外层手势（整卡点击 / 长按、右键菜单、订阅命中分流）留给调用方在壳外组合，
/// 不塞进本组件。测试锚点 Key 建议直接放在本组件上。
class AppCoverCard extends StatelessWidget {
  const AppCoverCard({
    super.key,
    required this.cover,
    this.infoBuilder,
    this.collapsedOverlay,
    this.hoverEnabled = true,
    this.coverAspectRatio,
    this.footer,
    this.overlays = const <Widget>[],
    this.overlaysBuilder,
    this.selectionMode = false,
    this.isSelected = false,
  });

  /// 封面内容（图片、占位块等）。悬停展开时会被 [AppCoverHoverInfo] 轻微推近。
  final Widget cover;

  /// 悬停展开的底部信息面板内容；为空时不组装悬停层（常驻标题类卡片）。
  final WidgetBuilder? infoBuilder;

  /// 收起态前景层（如影片番号、女优姓名）；悬停展开时淡出。
  final Widget? collapsedOverlay;

  /// 是否允许悬停展开（选择模式下传 `false`）。
  final bool hoverEnabled;

  /// 封面区比例；为空时封面直接铺满父约束。
  final double? coverAspectRatio;

  /// 封面区下方的常驻内容（合集卡的标题行）。
  final Widget? footer;

  /// 叠在封面区上的常驻角标，自行用 `Positioned` 定位。
  final List<Widget> overlays;

  /// 需要按卡片实际宽度排版角标时使用；结果追加在 [overlays] 之后。
  final List<Widget> Function(BuildContext context, BoxConstraints constraints)?
  overlaysBuilder;

  /// 选择模式：左上角叠加勾选徽标、边框切选中色。
  final bool selectionMode;

  /// 当前是否被选中（仅 [selectionMode] 下有意义）。
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final radius = context.appRadius.lgBorder;
    final selected = selectionMode && isSelected;

    Widget coverArea = cover;
    final info = infoBuilder;
    if (info != null) {
      coverArea = AppCoverHoverInfo(
        enabled: hoverEnabled,
        cover: coverArea,
        collapsedOverlay: collapsedOverlay,
        infoBuilder: info,
      );
    }

    final overlayBuilder = overlaysBuilder;
    if (overlays.isNotEmpty || overlayBuilder != null || selectionMode) {
      // 先取出当前值：闭包按引用捕获变量，直接引用 coverArea 会捕获下一次
      // 赋值（LayoutBuilder 自身）导致无限自我嵌套。
      final layeredCover = coverArea;
      coverArea = LayoutBuilder(
        builder: (context, constraints) => Stack(
          fit: StackFit.expand,
          children: [
            layeredCover,
            ...overlays,
            ...?overlayBuilder?.call(context, constraints),
            if (selectionMode)
              Positioned(
                top: spacing.xs,
                left: spacing.xs,
                child: IgnorePointer(
                  child: SelectionCheckBadge(isSelected: isSelected),
                ),
              ),
          ],
        ),
      );
    }

    final aspectRatio = coverAspectRatio;
    if (aspectRatio != null) {
      coverArea = AspectRatio(aspectRatio: aspectRatio, child: coverArea);
    }

    final footerContent = footer;
    final Widget content = footerContent == null
        ? coverArea
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [coverArea, footerContent],
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: radius,
        border: Border.all(
          color: selected ? colors.selectionBorder : colors.borderSubtle,
          width: selected ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        // 骨架态整卡收敛成一块 shimmer 圆角块（非骨架态原样渲染）。
        child: AppSkeletonUnite(borderRadius: radius, child: content),
      ),
    );
  }
}
