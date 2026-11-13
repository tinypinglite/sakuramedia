import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';

typedef PlayerSplitPanelBuilder = Widget Function(BuildContext context);

/// 播放器左右分栏的共享壳：桌面与移动端默认都展开右面板；[collapsible] 时右上角
/// 常显一个纯图标开关（与顶栏返回/信息按钮同一行），点击收起/展开，展开后仍可用
/// 分隔条拖拽调节宽度。
///
/// 收起/展开由右侧 [Area.flex] 驱动（0 = 收起）：收起时右侧子树卸载，展开时挂载；
/// 左侧子树始终挂在同一个 [MultiSplitView] 的同一位置，保证调用方的播放器 State
/// 不因开关面板重建。动画期间右侧内容按展开态宽度固定布局，只有外层裁切窗口随
/// 槽位收缩/展开（从右滑出/滑入），缩略图网格不会每帧重新布局；收起动画尾部槽位
/// 接近 0 宽，固定宽度裁切也避免给网格负的布局约束。
class CollapsiblePlayerSplitView extends StatefulWidget {
  const CollapsiblePlayerSplitView({
    super.key,
    required this.controller,
    required this.leftBuilder,
    required this.rightBuilder,
    this.dividerHandleBuffer = 0,
    this.collapsible = false,
    this.panelAvailable = true,
    this.handleKey,
    this.defaultPanelFlex = 0.28,
  });

  final MultiSplitViewController controller;
  final PlayerSplitPanelBuilder leftBuilder;
  final PlayerSplitPanelBuilder rightBuilder;
  final double dividerHandleBuffer;

  /// 传 true：右上角常显展开/收起开关（默认展开，点击收起/再展开）。
  final bool collapsible;

  /// 右侧面板是否有内容可展示；无内容时不显示开关。
  final bool panelAvailable;
  final Key? handleKey;

  /// 首次展开时使用的面板 flex，也是记忆宽度的兜底值。
  final double defaultPanelFlex;

  @override
  State<CollapsiblePlayerSplitView> createState() =>
      _CollapsiblePlayerSplitViewState();
}

class _CollapsiblePlayerSplitViewState extends State<CollapsiblePlayerSplitView>
    with SingleTickerProviderStateMixin {
  static const Duration _animationDuration = Duration(milliseconds: 220);
  static const Curve _animationCurve = Curves.easeOutCubic;
  static const double _collapsedFlexThreshold = 0.0001;
  static const double _rememberedFlexFloor = 0.04;

  /// 收起/展开动画途中，右侧面板内容至少按此像素宽度布局再裁切，避免面板槽位
  /// 接近 0 宽时缩略图网格拿到负的布局约束。
  static const double _minPanelContentWidth = 48;

  late final AnimationController _animationController;
  double _animationBeginFlex = 0;
  double _animationEndFlex = 0;
  double _rememberedPanelFlex = 0.28;
  bool _expanded = true;

  MultiSplitViewController get _controller => widget.controller;
  double get _panelFlex => _controller.areas[1].flex ?? 0;

  @override
  void initState() {
    super.initState();
    _rememberedPanelFlex = widget.defaultPanelFlex;
    _animationController = AnimationController(
      vsync: this,
      duration: _animationDuration,
    )..addListener(_applyFlexAnimationTick);
    if (!widget.panelAvailable) {
      _controller.areas[1].flex = 0;
    } else if (_panelFlex >= _rememberedFlexFloor) {
      _rememberedPanelFlex = _panelFlex;
    }
    _expanded = _panelFlex > _collapsedFlexThreshold;
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant CollapsiblePlayerSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.panelAvailable && _expanded) {
      _animatePanelFlexTo(0);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    final flex = _panelFlex;
    if (!_animationController.isAnimating && flex >= _rememberedFlexFloor) {
      _rememberedPanelFlex = flex;
    }
    // layout 由 MultiSplitView 自己监听 controller 完成；这里只在展开/收起翻转时
    // 重建，用来挂载/卸载右侧子树和切换图标，避免动画每帧重建整棵分栏。
    final expanded = flex > _collapsedFlexThreshold;
    if (expanded != _expanded) {
      _expanded = expanded;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _applyFlexAnimationTick() {
    final progress = _animationCurve.transform(_animationController.value);
    _controller.areas[1].flex =
        _animationBeginFlex +
        (_animationEndFlex - _animationBeginFlex) * progress;
  }

  void _animatePanelFlexTo(double target) {
    final from = _panelFlex;
    if ((from - target).abs() < _collapsedFlexThreshold) {
      _animationBeginFlex = target;
      _animationEndFlex = target;
      _controller.areas[1].flex = target;
      return;
    }
    _animationBeginFlex = from;
    _animationEndFlex = target;
    _animationController.forward(from: 0);
  }

  void _togglePanel() {
    if (_animationController.isAnimating) {
      // 动画途中点击：反向动画。不读当前 flex 当记忆宽度，避免把中间值当成
      // 「上次宽度」，收起再展开后宽度变样。
      _animatePanelFlexTo(
        _animationEndFlex > _collapsedFlexThreshold ? 0 : _rememberedPanelFlex,
      );
      return;
    }
    if (_panelFlex > _collapsedFlexThreshold) {
      if (_panelFlex >= _rememberedFlexFloor) {
        _rememberedPanelFlex = _panelFlex;
      }
      _animatePanelFlexTo(0);
      return;
    }
    _animatePanelFlexTo(_rememberedPanelFlex);
  }

  double _panelPixelWidth(double flex, double available) {
    final otherFlex = _controller.areas[0].flex ?? 1;
    final totalFlex = otherFlex + flex;
    if (totalFlex <= 0) {
      return 0;
    }
    return available * flex / totalFlex;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final showToggle = widget.collapsible && widget.panelAvailable;
    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: spacing.xs,
        dividerHandleBuffer: widget.dividerHandleBuffer,
        dividerPainter: DividerPainters.grooved1(
          color: context.appColors.borderSubtle,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final available = math.max(constraints.maxWidth - spacing.xs, 0.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              MultiSplitView(
                controller: widget.controller,
                axis: Axis.horizontal,
                builder: (context, area) => area.index == 0
                    ? widget.leftBuilder(context)
                    : _expanded
                    ? _buildClippedPanel(context, available)
                    : const SizedBox.shrink(),
              ),
              if (showToggle)
                Positioned.fill(child: _buildToggleOverlay(context, available)),
            ],
          );
        },
      ),
    );
  }

  /// 面板槽位宽度随收起/展开动画收缩。动画期间内容按展开态宽度固定布局，
  /// 只有外层 [ClipRect] 窗口和内容偏移在动，网格全程不重新布局；非动画时
  /// （拖拽分隔条 / 窗口缩放）内容按当前 flex 跟随槽位宽度。
  Widget _buildClippedPanel(BuildContext context, double available) {
    final contentWidth = math.max(
      _panelPixelWidth(
        _animationController.isAnimating ? _rememberedPanelFlex : _panelFlex,
        available,
      ),
      _minPanelContentWidth,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(constraints.maxWidth, contentWidth);
        // 内容左缘贴槽位左缘：收起时槽位左缘右移，内容整体向右滑出被裁掉。
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: width,
            maxWidth: width,
            minHeight: constraints.minHeight,
            maxHeight: constraints.maxHeight,
            child: widget.rightBuilder(context),
          ),
        );
      },
    );
  }

  /// 右上角常显的面板开关：定位跟随**播放画面（左面板）的右缘** —— 收起时贴屏幕
  /// 右上角，展开时随分隔条左移，停在顶栏「视频信息」按钮旁，不落到右侧面板上。
  ///
  /// 位置由 [ListenableBuilder] 监听 controller 逐帧计算，动画/拖拽时只重建这个
  /// 小按钮，不重建分栏与播放器。
  Widget _buildToggleOverlay(BuildContext context, double available) {
    final overlayTokens = context.appOverlayTokens;
    final button = AppIconButton(
      key: widget.handleKey,
      size: AppIconButtonSize.regular,
      iconColor: context.appTextPalette.onMedia,
      semanticLabel: _expanded
          ? AppLocalizations.of(context).widgetMediaThumbnailPanelCollapse
          : AppLocalizations.of(context).widgetMediaThumbnailPanelExpand,
      onPressed: _togglePanel,
      icon: Icon(
        _expanded ? Icons.chevron_right_rounded : Icons.grid_view_rounded,
        size: context.appComponentTokens.iconSizeSm,
        // 常显在画面上，加轻描影保证亮画面下也可读。
        shadows: <Shadow>[
          Shadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 8),
        ],
      ),
    );
    return ListenableBuilder(
      listenable: widget.controller,
      child: button,
      builder: (context, child) {
        final spacing = context.appSpacing;
        final panelWidth = _panelPixelWidth(_panelFlex, available);
        // 不叠 SafeArea：media_kit 窗口态顶栏用的就是零安全区内边距，开关要
        // 和「视频信息」按钮同锚点，多塞一层安全区会在带刘海的设备上横向错开。
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.only(
              // 与 media_kit 顶栏按钮同一行：顶栏是 56 高容器（top margin 18）
              // 内垂直居中 44 的按钮，按钮实际 top = 18 + （56-44）/2 = 24，
              // 正是 playerBackOverlayTop；用 18 会低 6px、与信息按钮错位。
              top: overlayTokens.playerBackOverlayTop,
              // 与顶栏同一坐标系：都相对左侧播放画面的右缘内缩，而不是相对
              // 整个分栏，展开时才能停在播放画面右上角、不落到右侧面板上。
              right:
                  panelWidth +
                  spacing.xs +
                  overlayTokens.playerControlBarHorizontalInset,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
