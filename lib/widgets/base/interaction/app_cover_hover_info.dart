import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 封面卡片的桌面悬停披露层：收起态只显示封面，指针悬停时底部渐显压暗层、
/// 信息自下而上淡入。
///
/// 与 `MovieSummaryCard` 的悬停范式一致：180ms ease-out；压暗渐变（黑 0.44 →
/// 0.72 + 1px 顶部高光）保证白字在任意封面上可读；系统开启「减弱动态效果」时
/// 退化为瞬时切换。触摸端没有 hover，收起态面板不进树、不参与命中测试，不挡
/// 整卡点击；选择模式等场景由 [enabled] 关闭展开。
class AppCoverHoverInfo extends StatefulWidget {
  const AppCoverHoverInfo({
    super.key,
    required this.cover,
    required this.infoBuilder,
    this.enabled = true,
  });

  /// 收起态内容（封面）。悬停时整体轻微放大。
  final Widget cover;

  /// 悬停展开的底部信息面板内容。
  final WidgetBuilder infoBuilder;

  /// 是否允许悬停展开（选择模式下传 `false`）。
  final bool enabled;

  /// 悬停时封面推近的幅度。网格 gutter ≥ 16，1.03 不会压到相邻卡片。
  static const double _coverScale = 1.03;

  /// 展开/收起的过渡时长：短到不打断扫视，长得足以看清内容。
  static const Duration _duration = Duration(milliseconds: 180);

  @override
  State<AppCoverHoverInfo> createState() => _AppCoverHoverInfoState();
}

class _AppCoverHoverInfoState extends State<AppCoverHoverInfo> {
  bool _hovered = false;

  bool get _expanded => _hovered && widget.enabled;

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : AppCoverHoverInfo._duration;
    final expanded = _expanded;
    final panel = _CoverHoverPanel(child: widget.infoBuilder(context));

    final Widget overlay;
    if (reduceMotion) {
      overlay = expanded ? panel : const SizedBox.shrink();
    } else {
      overlay = AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.bottomLeft,
          children: <Widget>[...previousChildren, ?currentChild],
        ),
        child: KeyedSubtree(
          key: ValueKey<bool>(expanded),
          child: expanded ? panel : const SizedBox.shrink(),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedScale(
            scale: expanded ? AppCoverHoverInfo._coverScale : 1,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: widget.cover,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(ignoring: !expanded, child: overlay),
          ),
        ],
      ),
    );
  }
}

/// 悬停信息面板：底部压暗渐变 + 1px 顶部高光。
///
/// 不用 [BackdropFilter]：卡片本身带 `clipBehavior` 与阴影（saveLayer），模糊会
/// 溢出面板范围；压暗渐变在浅色与深色封面上都能保证白字可读。
class _CoverHoverPanel extends StatelessWidget {
  const _CoverHoverPanel({required this.child});

  final Widget child;

  static const double _dimTopAlpha = 0.44;
  static const double _dimBottomAlpha = 0.72;
  static const double _hairlineAlpha = 0.12;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    // Positioned(left/right) 给的是宽松约束：显式撑满宽度，避免面板按内容收缩。
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: _dimTopAlpha),
              Colors.black.withValues(alpha: _dimBottomAlpha),
            ],
          ),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: _hairlineAlpha),
              width: 1,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.sm,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 悬停面板的信息行：「主标签 + 副信息」单行。
///
/// 主标签先用 [Flexible] 截断，副信息保持常显——卡片宽度有限时先牺牲标题，
/// 不牺牲番号 / 时长等识别信息。动作按钮不放在这里，统一由
/// [AppCoverHoverActionBar] 在信息行下方铺满一整行。
class AppCoverHoverInfoRow extends StatelessWidget {
  const AppCoverHoverInfoRow({super.key, required this.label, this.meta});

  /// 主标签（切片标题 / 时刻番号）。
  final String label;

  /// 副信息（番号 · 时长 · 大小 / 类型 · 位置等），为空时省略。
  final String? meta;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final metaText = meta?.trim();
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveCoverOverlayTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.semibold,
                ),
              ),
            ),
            if (metaText != null && metaText.isNotEmpty) ...[
              SizedBox(width: spacing.sm),
              ConstrainedBox(
                // 副信息最多占信息行的 8 成：保证番号 / 时长尽量常显，
                // 大字体或宽字形时先截副信息，剩余空间留给主标签。
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.8,
                ),
                child: Text(
                  metaText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: resolveCoverOverlayTextStyle(
                    context,
                    size: AppTextSize.s10,
                    opacity: 0.72,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 悬停面板的动作行：信息行下方一整行圆形图标按钮，全站卡片统一。
///
/// 调用方按当前上下文把可用动作依次传入；行动作按 [Wrap] 排列，窄卡片自动
/// 折行。动作调用方负责为每个按钮提供稳定的测试 Key。
class AppCoverHoverActionBar extends StatelessWidget {
  const AppCoverHoverActionBar({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      // 间距取 xs/2：窄卡片（约 180 逻辑宽）也能让 5 个动作保持一行。
      spacing: context.appSpacing.xs / 2,
      runSpacing: context.appSpacing.xs / 2,
      children: actions,
    );
  }
}

/// 悬停面板动作行里的圆形图标按钮。
///
/// [primary] 为播放等主操作：白底实心圆 + 品牌色图标；其余动作为半透明白底 +
/// 白图标，保证在压暗渐变上可读。`onTap` 为 `null` 时只作占位（不响应点击）。
class AppCoverHoverActionButton extends StatelessWidget {
  const AppCoverHoverActionButton({
    super.key,
    required this.icon,
    this.onTap,
    this.primary = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;

  /// 主操作用白底实心（当前只有播放），次操作用半透明白底。
  final bool primary;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appComponentTokens;
    final tooltipText = tooltip;
    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Container(
          width: tokens.iconSize2xl,
          height: tokens.iconSize2xl,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary
                ? Colors.white
                : Colors.white.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: tokens.iconSizeMd,
            color: primary
                ? context.appTextPalette.primary
                : context.appTextPalette.onMedia,
          ),
        ),
      ),
    );
    if (tooltipText == null || tooltipText.isEmpty) {
      return button;
    }
    return Tooltip(message: tooltipText, child: button);
  }
}

/// 封面悬停面板上的白字样式：onMedia 色 + macOS 行高/字距（与影片卡一致）。
TextStyle resolveCoverOverlayTextStyle(
  BuildContext context, {
  required AppTextSize size,
  AppTextWeight weight = AppTextWeight.regular,
  double opacity = 1,
}) {
  final base = switch (size) {
    AppTextSize.s12 => resolveAppTextStyle(
      context,
      size: size,
      weight: weight,
      tone: AppTextTone.onMedia,
      height: 16 / 13,
      letterSpacing: -0.08,
    ),
    AppTextSize.s10 => resolveAppTextStyle(
      context,
      size: size,
      weight: weight,
      tone: AppTextTone.onMedia,
      height: 13 / 10,
      letterSpacing: 0.12,
    ),
    _ => resolveAppTextStyle(
      context,
      size: size,
      weight: weight,
      tone: AppTextTone.onMedia,
    ),
  };
  if (opacity >= 1) {
    return base;
  }
  return base.copyWith(color: base.color?.withValues(alpha: opacity));
}
