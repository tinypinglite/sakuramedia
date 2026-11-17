import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

/// 「封面贴左」样式的白底列表卡片外壳，供跨 feature 复用。
///
/// - 布局：`Container(clipAntiAlias) + Stack + PositionedDirectional`。右侧内容
///   `Padding(start: coverWidth)` 让位、决定 Stack 高度；左侧封面 `Positioned`
///   在 `(coverWidth × Stack 高度)` tight 约束下一次布局到位，避免 `Row(stretch)`
///   与 `MaskedImage` 内 `LayoutBuilder` 在 loose height 下的 race。
/// - 视觉：`surfaceCard` 白底 + `mdBorder` 圆角 + `borderSubtle` 细边；选中态
///   切 `selectionBorder`（品牌樱酒红 `#6B2D2A`，**只换颜色不改宽度**，避免 1↔2
///   像素的 layout 跳动）。
/// - 可选整卡点击：`onTap`/`onLongPress` 非空时套 [AppInteractiveSurface]，
///   反馈统一走"整块加深"（无涟漪），形状跟随卡片圆角；为空时不套
///   （整卡不可点，交互留给 slot 内的按钮）。
///
/// 封面本身的独立可点（比如"点封面 → 跳详情"）由调用方在 [cover] slot 内自行
/// 包装——内层手势拦截不冒泡到外层，两层交互天然分离。
///
/// 现有调用点：`_MediaRow`（媒体管理）、`DownloadTaskCard`（下载任务）。
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
    this.onLongPress,
    this.shell = true,
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

  /// 整卡长按回调（移动端进入多选等）。非空时同样套交互表面，按下有反馈。
  final VoidCallback? onLongPress;

  /// 是否绘制自带卡片壳（白底、圆角、细边）。`false` 时只出「贴边封面 + 内容」
  /// 布局，供调用方在自有卡片壳内复用（如分组卡组头）。
  final bool shell;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final radius = context.appRadius.mdBorder;
    final resolvedBodyPadding =
        bodyPadding ?? EdgeInsets.all(context.appSpacing.lg);

    Widget rightContent = Padding(padding: resolvedBodyPadding, child: body);
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

    Widget layout = Stack(children: [rightContent, leftCover]);
    if (shell) {
      layout = Container(
        width: double.infinity,
        // clipAntiAlias 让内容按 borderRadius 裁剪：封面直接贴到左边框内侧，无缝隙。
        // border 由 decoration 绘制在容器外围，clip 区域是 border 内侧——封面不会
        // 覆盖 border。
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: radius,
          border: Border.all(
            color: selected ? colors.selectionBorder : colors.borderSubtle,
          ),
        ),
        child: layout,
      );
    }

    if (onTap != null || onLongPress != null) {
      layout = AppInteractiveSurface(
        onTap: onTap,
        onLongPress: onLongPress,
        child: layout,
      );
    }
    return layout;
  }
}
