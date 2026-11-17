import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';

typedef AppGlassAnchoredMenuTriggerBuilder =
    Widget Function(BuildContext context, bool isOpen, VoidCallback toggle);
typedef AppGlassAnchoredMenuContentBuilder =
    Widget Function(BuildContext context, VoidCallback close);

/// 控制已插入的锚定菜单；用于侧栏收起等外部场景强制关闭。
class AppGlassAnchoredMenuController {
  _AppGlassAnchoredMenuState? _state;

  bool get isOpen => _state?._isOpen ?? false;

  void close() => _state?._removeOverlay();
}

/// 紧凑的锚定下拉菜单。
///
/// 触发器由调用方提供；面板统一使用 [AppSurface]，行项目建议使用
/// [AppGlassMenuRow]。菜单宽度跟随触发器，空间不足时自动向上展开，内容超过
/// 可用高度时在面板内滚动。
class AppGlassAnchoredMenu extends StatefulWidget {
  const AppGlassAnchoredMenu({
    super.key,
    required this.triggerBuilder,
    required this.contentBuilder,
    this.controller,
    this.panelKey,
    this.scrollViewKey,
    this.width,
    this.minWidth = 160,
    this.maxWidth = 320,
    this.estimatedHeight = 240,
    this.maxHeight,
    this.borderRadius,
    this.screenPadding = const EdgeInsets.all(16),
    this.gap = 4,
    this.onOpen,
    this.onClose,
  });

  final AppGlassAnchoredMenuTriggerBuilder triggerBuilder;
  final AppGlassAnchoredMenuContentBuilder contentBuilder;
  final AppGlassAnchoredMenuController? controller;
  final Key? panelKey;
  final Key? scrollViewKey;
  final double? width;
  final double minWidth;
  final double maxWidth;
  final double estimatedHeight;
  final double? maxHeight;
  final BorderRadius? borderRadius;
  final EdgeInsets screenPadding;
  final double gap;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  @override
  State<AppGlassAnchoredMenu> createState() => _AppGlassAnchoredMenuState();
}

class _AppGlassAnchoredMenuState extends State<AppGlassAnchoredMenu> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  final FocusNode _menuFocusNode = FocusNode(
    debugLabel: 'AppGlassAnchoredMenu',
  );

  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _opensUpward = false;
  double _menuWidth = 0;
  double _menuMaxHeight = 0;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(covariant AppGlassAnchoredMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._state = null;
      widget.controller?._state = this;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) {
      widget.controller?._state = null;
    }
    _removeOverlay(notify: false, callOnClose: false);
    _menuFocusNode.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }
    _showOverlay();
  }

  void _showOverlay() {
    final triggerBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context);
    if (triggerBox == null || !triggerBox.hasSize) {
      return;
    }

    final viewport = MediaQuery.sizeOf(context);
    final triggerTopLeft = triggerBox.localToGlobal(Offset.zero);
    final triggerBottom = triggerTopLeft.dy + triggerBox.size.height;
    final availableWidth = math.max(
      80.0,
      viewport.width - widget.screenPadding.horizontal,
    );
    final resolvedMaxWidth = math.min(widget.maxWidth, availableWidth);
    final resolvedMinWidth = math.min(widget.minWidth, resolvedMaxWidth);
    final desiredWidth = widget.width ?? triggerBox.size.width;
    _menuWidth = desiredWidth
        .clamp(resolvedMinWidth, resolvedMaxWidth)
        .toDouble();

    final desiredHeight = math.min(
      widget.estimatedHeight,
      widget.maxHeight ?? viewport.height * 0.65,
    );
    final spaceBelow =
        viewport.height - triggerBottom - widget.screenPadding.bottom;
    final spaceAbove = triggerTopLeft.dy - widget.screenPadding.top;
    _opensUpward =
        spaceBelow < desiredHeight + widget.gap && spaceAbove > spaceBelow;
    final availableHeight = math.max(
      80.0,
      (_opensUpward ? spaceAbove : spaceBelow) - widget.gap,
    );
    _menuMaxHeight = math.min(desiredHeight, availableHeight);

    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_overlayEntry!);
    setState(() => _isOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _overlayEntry != null) {
        _menuFocusNode.requestFocus();
      }
    });
    widget.onOpen?.call();
  }

  Widget _buildOverlay(BuildContext context) {
    final panel = Focus(
      focusNode: _menuFocusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _removeOverlay();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        type: MaterialType.transparency,
        child: AppSurface(
          key: widget.panelKey,
          width: _menuWidth,
          borderRadius: widget.borderRadius ?? context.appRadius.mdBorder,
          role: AppSurfaceRole.popover,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: _menuMaxHeight),
            child: SingleChildScrollView(
              key: widget.scrollViewKey,
              primary: false,
              child: widget.contentBuilder(context, _removeOverlay),
            ),
          ),
        ),
      ),
    );

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _removeOverlay,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: _opensUpward ? Alignment.topLeft : Alignment.bottomLeft,
          followerAnchor: _opensUpward
              ? Alignment.bottomLeft
              : Alignment.topLeft,
          offset: Offset(0, _opensUpward ? -widget.gap : widget.gap),
          child: panel,
        ),
      ],
    );
  }

  void _removeOverlay({bool notify = true, bool callOnClose = true}) {
    final entry = _overlayEntry;
    if (entry == null) {
      return;
    }
    _overlayEntry = null;
    entry.remove();
    entry.dispose();
    _menuFocusNode.unfocus();
    if (notify && mounted) {
      setState(() => _isOpen = false);
    } else {
      _isOpen = false;
    }
    if (callOnClose) {
      widget.onClose?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: KeyedSubtree(
        key: _triggerKey,
        child: widget.triggerBuilder(context, _isOpen, _toggle),
      ),
    );
  }
}

/// 玻璃锚定菜单里的标准行。
///
/// 行本身不画 hover；按压反馈由 [AppInteractiveSurface] 统一处理。
class AppGlassMenuRow extends StatelessWidget {
  const AppGlassMenuRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.selected = false,
    this.showCheckmark = false,
    this.enabled = true,
    this.onTap,
    this.minHeight = 36,
    this.padding,
    this.titleStyle,
    this.subtitleStyle,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final bool showCheckmark;
  final bool enabled;
  final VoidCallback? onTap;
  final double minHeight;
  final EdgeInsetsGeometry? padding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final resolvedTitleStyle =
        titleStyle ??
        resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: selected ? AppTextWeight.medium : AppTextWeight.regular,
          tone: !enabled
              ? AppTextTone.muted
              : selected
              ? AppTextTone.accent
              : AppTextTone.primary,
        );
    final resolvedSubtitleStyle =
        subtitleStyle ??
        resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          tone: AppTextTone.muted,
        );

    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding:
            padding ??
            EdgeInsets.symmetric(horizontal: spacing.md, vertical: spacing.xs),
        child: Row(
          children: <Widget>[
            if (leading != null) ...[leading!, SizedBox(width: spacing.sm)],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DefaultTextStyle.merge(
                    style: resolvedTitleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 2),
                    DefaultTextStyle.merge(
                      style: resolvedSubtitleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[SizedBox(width: spacing.sm), trailing!],
            if (showCheckmark && selected)
              Padding(
                padding: EdgeInsets.only(left: spacing.xs),
                child: Icon(
                  Icons.check_rounded,
                  size: context.appComponentTokens.iconSizeSm,
                  color: colors.selectionBorder,
                ),
              ),
          ],
        ),
      ),
    );

    return Semantics(
      button: enabled && onTap != null,
      enabled: enabled,
      selected: showCheckmark ? selected : null,
      child: AppInteractiveSurface(
        enabled: enabled,
        onTap: enabled ? onTap : null,
        focusRingRadius: context.appRadius.smBorder,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? colors.surfaceMuted : Colors.transparent,
            borderRadius: context.appRadius.smBorder,
          ),
          child: row,
        ),
      ),
    );
  }
}
