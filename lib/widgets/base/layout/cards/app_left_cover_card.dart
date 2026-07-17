import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 「封面贴左」样式的白底列表卡片外壳，供跨 feature 复用。
///
/// - 布局：`Container(clipAntiAlias) + Stack + PositionedDirectional`。右侧内容
///   `Padding(start: coverWidth)` 让位、决定 Stack 高度；左侧封面 `Positioned`
///   在 `(coverWidth × Stack 高度)` tight 约束下一次布局到位，避免 `Row(stretch)`
///   与 `MaskedImage` 内 `LayoutBuilder` 在 loose height 下的 race。
/// - 视觉：`surfaceCard` 白底 + `mdBorder` 圆角 + `borderSubtle` 细边；选中态
///   切品牌 `appTextPalette.accent`（**只换颜色不改宽度**，避免 1↔2 像素的 layout
///   跳动）。历史 token `selectionBorder` 是 Ant 蓝 `#1677FF`，跟 sakura 深酒红
///   品牌色不搭——这里显式走 palette accent，不复用它。
/// - 可选整卡点击：`onTap` 非空时套 `Material + InkWell`，水波纹由 clipAntiAlias
///   自然裁剪；`onTap` 为空时不套（整卡不可点，交互留给 slot 内的按钮/子 InkWell）。
///
/// 封面本身的独立可点（比如"点封面 → 跳详情"）由调用方在 [cover] slot 内自行
/// 用 `InkWell` 包装——内层 InkWell 拦截手势不冒泡到外层，两层交互天然分离。
///
/// 现有调用点：`_MediaRow`（媒体管理）、`_DownloadTaskCard`（下载任务）。
class AppLeftCoverCard extends StatelessWidget {
  const AppLeftCoverCard({
    super.key,
    required this.cover,
    required this.body,
    required this.coverWidth,
    this.bodyMinHeight,
    this.bodyPadding,
    this.selected = false,
    this.onTap,
  });

  /// 左侧封面 slot——直接铺在 `(coverWidth × 卡片高度)` 内，圆角由外层裁剪。
  /// 需要"点封面独立跳转"的调用方，在此 widget 内部自己套 `InkWell`。
  final Widget cover;

  /// 右侧内容 slot——由它决定卡片高度。
  final Widget body;

  final double coverWidth;

  /// 卡片最低高度（一般传 coverHeight，保证内容行数少时封面不会被压扁）。
  final double? bodyMinHeight;

  /// [body] 外的内边距，默认 `EdgeInsets.all(spacing.lg)`。
  final EdgeInsetsGeometry? bodyPadding;

  /// 选中态：切边框色为 `selectionBorder`。
  final bool selected;

  /// 整卡点击回调；`null` 时不套 InkWell（整卡不可点）。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final palette = context.appTextPalette;
    final radius = context.appRadius.mdBorder;
    final resolvedBodyPadding =
        bodyPadding ?? EdgeInsets.all(context.appSpacing.lg);

    Widget rightContent = Padding(
      padding: resolvedBodyPadding,
      child: body,
    );
    if (bodyMinHeight != null) {
      rightContent = ConstrainedBox(
        constraints: BoxConstraints(minHeight: bodyMinHeight!),
        child: rightContent,
      );
    }
    rightContent = Padding(
      padding: EdgeInsetsDirectional.only(start: coverWidth),
      child: rightContent,
    );

    final leftCover = PositionedDirectional(
      top: 0,
      bottom: 0,
      start: 0,
      width: coverWidth,
      child: cover,
    );

    Widget card = Container(
      width: double.infinity,
      // clipAntiAlias 让内容按 borderRadius 裁剪：封面直接贴到左边框内侧，无缝隙。
      // border 由 decoration 绘制在容器外围，clip 区域是 border 内侧——封面不会
      // 覆盖 border。
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: radius,
        border: Border.all(
          color: selected ? palette.accent : colors.borderSubtle,
        ),
      ),
      child: Stack(children: [rightContent, leftCover]),
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: card,
        ),
      );
    }
    return card;
  }
}
