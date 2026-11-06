import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:sakuramedia/core/platform/haptic_feedback.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_focus_ring.dart';

/// 全项目统一的**交互态表面**：所有可点元素都应经过它，不要各自写 `InkWell`。
///
/// 三条设计约束，改之前先读：
///
/// 1. **不用 Material 涟漪。** 国内主流按下反馈不是水波纹；`material_ui` 在
///    `useMaterial3` 下默认会画 InkRipple / InkSparkle，这里统一用
///    [NoSplash.splashFactory] 关掉。
/// 2. **没有 hover / 按下底色。** 桌面 hover 不做任何视觉变化——移动端没有
///    hover，两端保持一致，可点性提示只有鼠标手型和 tooltip；按下也不叠
///    "底下一块灰"，叠底色在浅色背景上会像"选中态"而不是"按下"。
/// 3. **按下 = 整体变淡。** 走 [pressedOpacity] 的整体透明度（默认 0.7，
///    同国内移动端主流与微信默认按压值）。调用方画在 child 上的选中态底色
///    会跟着一起变淡，不会被盖掉。
class AppInteractiveSurface extends StatefulWidget {
  const AppInteractiveSurface({
    super.key,
    required this.child,
    this.onTap,
    this.onTapDown,
    this.onLongPress,
    this.onSecondaryTap,
    this.enabled = true,
    this.pressedOpacity = 0.7,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.focusRing = true,
    this.focusRingRadius,
    this.focusRingColor,
    this.focusNode,
  });

  final Widget child;
  final VoidCallback? onTap;
  final GestureTapDownCallback? onTapDown;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  /// false 时不可点、无反馈；"视觉禁用"（降透明度、换前景色）由调用方决定。
  final bool enabled;

  /// 按下时整体透明度。默认 0.7：能看出"整个元素一起变淡"，又明显轻于
  /// 禁用态（0.56）。数值越小按下越重。
  final double pressedOpacity;

  final String? semanticLabel;
  final bool excludeFromSemantics;

  /// 键盘聚焦时是否绘制 2px 焦点环。默认开启。
  final bool focusRing;

  /// 焦点环圆角；不传时使用主题的小圆角。
  final BorderRadius? focusRingRadius;
  final Color? focusRingColor;

  /// 可选外部焦点节点；不传时由 InkWell 自持。
  final FocusNode? focusNode;

  @override
  State<AppInteractiveSurface> createState() => _AppInteractiveSurfaceState();
}

class _AppInteractiveSurfaceState extends State<AppInteractiveSurface> {
  bool _pressed = false;
  bool _focused = false;

  void _handleFocusChange(bool focused) {
    if (_focused == focused) {
      return;
    }
    setState(() => _focused = focused);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final interactive =
        widget.enabled &&
        (widget.onTap != null ||
            widget.onLongPress != null ||
            widget.onSecondaryTap != null);
    if (!interactive ||
        widget.onTap == null ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent) ||
        (event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.space)) {
      return KeyEventResult.ignored;
    }
    widget.onTap!();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final interactive =
        widget.enabled &&
        (widget.onTap != null ||
            widget.onLongPress != null ||
            widget.onSecondaryTap != null);

    Widget surface = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleKeyEvent,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: interactive ? widget.onTap : null,
          onTapDown: interactive ? widget.onTapDown : null,
          // 长按统一补一次轻触感（移动端长按进多选/弹菜单的高频入口）。
          onLongPress: interactive && widget.onLongPress != null
              ? () {
                  triggerSelectionHaptic();
                  widget.onLongPress!();
                }
              : null,
          onSecondaryTap: interactive ? widget.onSecondaryTap : null,
          onHighlightChanged: interactive
              ? (highlighted) {
                  if (_pressed != highlighted) {
                    setState(() => _pressed = highlighted);
                  }
                }
              : null,
          mouseCursor: interactive
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          // InkWell 自带的 ink 反馈全部关掉，按下视觉统一由 Opacity 表达。
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          canRequestFocus: interactive && widget.onTap != null,
          focusNode: widget.focusNode,
          onFocusChange: interactive ? _handleFocusChange : null,
          excludeFromSemantics: widget.excludeFromSemantics,
          child: AnimatedOpacity(
            opacity: _pressed ? widget.pressedOpacity : 1,
            duration: const Duration(milliseconds: 80),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );

    final resolvedLabel = widget.semanticLabel;
    if (resolvedLabel != null && resolvedLabel.isNotEmpty) {
      surface = Semantics(button: true, label: resolvedLabel, child: surface);
    }
    return AppFocusRing(
      focused: interactive && widget.focusRing && _focused,
      borderRadius: widget.focusRingRadius ?? context.appRadius.smBorder,
      color: widget.focusRingColor,
      child: surface,
    );
  }
}
