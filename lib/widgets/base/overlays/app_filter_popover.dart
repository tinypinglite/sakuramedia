import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 通用「触发按钮 + 展开浮层面板」外壳。
///
/// actor / movie / ranking 三个 FilterToolbar 的浮层骨架
/// (LayerLink / OverlayEntry / CompositedTransformFollower /
/// GestureDetector 遮罩 / 面板 Container + panel) 逐行雷同,
/// 由本组件封死。调用方只提供:
///   - trigger 文案 / 高亮语义 / 面板宽度增量;
///   - 面板 body(`panelBuilder`);
///   - 可选 footer(通常用 [AppFilterPanelFooter])。
///
/// 面板内容一律包在 `Flexible(SingleChildScrollView)` 里,
/// 保证矮窗口不溢出。footer(若有)在滚动区之外。
class AppFilterPopover extends StatefulWidget {
  const AppFilterPopover({
    super.key,
    required this.triggerLabel,
    required this.panelBuilder,
    required this.panelKey,
    this.footer,
    this.triggerKey,
    this.labelKey,
    this.isSelected = false,
    this.highlightWhenOpen = true,
    this.enabled = true,
    this.panelExtraWidth = 180,
    this.scrollViewKey,
    this.onOpened,
    this.initialTriggerSize = const Size(160, 36),
    this.alignment = AppFilterPopoverAlignment.rightAlignedToTrigger,
    this.triggerBuilder,
  });

  final String triggerLabel;
  final WidgetBuilder panelBuilder;
  final Widget? footer;

  /// 面板容器上的 Key(actors-filter-panel / movies-filter-panel /
  /// rankings-filter-panel 等测试锚点)。
  final Key panelKey;

  final Key? triggerKey;
  final Key? labelKey;

  /// 外部高亮条件——不含"打开面板"这一状态。
  final bool isSelected;

  /// 打开面板时是否连带高亮 trigger,默认 true(actor / ranking)。
  /// movie 语义是"默认或自定义时高亮,与是否打开无关",传 false。
  final bool highlightWhenOpen;

  /// 触发按钮是否可点击。ranking 用 `!isLoading` 传入。
  final bool enabled;

  /// 面板宽度 = trigger 宽度 + panelExtraWidth,再按 overlay 宽度 clamp。
  final double panelExtraWidth;

  /// 面板内滚动区域的 Key(仅 movie 传 `Key('movies-filter-scroll-view')`
  /// 用于测试)。
  final Key? scrollViewKey;

  /// 打开面板前的回调（如女优详情预取年份选项）。
  final VoidCallback? onOpened;

  final Size initialTriggerSize;

  /// 面板相对 trigger 的对齐方式。
  /// - `rightAlignedToTrigger`（默认，movie / actor / ranking）：面板右边缘对齐
  ///   trigger 右边缘，多出来的宽度向左延伸；trigger 靠右时看起来自然。
  /// - `leftAlignedToTrigger`：面板左边缘对齐 trigger 左边缘，多出来的宽度
  ///   向右延伸；trigger 位于容器左侧、且右侧有富余空间时更合适。
  final AppFilterPopoverAlignment alignment;

  /// 自定义触发按钮；不传时用默认的 [AppTextButton] 样式。
  ///
  /// 列表顶栏传 `AppFilterEntryButton`，让桌面浮层入口与移动抽屉入口**长得一样**
  /// ——两端只有展开容器不同。回调给出 `isOpen` 与 `toggle`。
  final Widget Function(BuildContext context, bool isOpen, VoidCallback toggle)?
  triggerBuilder;

  @override
  State<AppFilterPopover> createState() => _AppFilterPopoverState();
}

enum AppFilterPopoverAlignment { rightAlignedToTrigger, leftAlignedToTrigger }

class _AppFilterPopoverState extends State<AppFilterPopover> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _overlayRebuildScheduled = false;
  late Size _triggerSize = widget.initialTriggerSize;
  Offset _triggerOffsetInOverlay = Offset.zero;

  static const double _panelVerticalGap = 8;

  @override
  void didUpdateWidget(covariant AppFilterPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleOverlayRebuild();
  }

  @override
  void dispose() {
    _removeOverlay(updateState: false);
    super.dispose();
  }

  void _togglePanel() {
    if (!widget.enabled) {
      return;
    }
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    widget.onOpened?.call();
    _updateTriggerMetrics();
    _isOpen = true;
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => _buildOverlay(overlayContext),
    );
    Overlay.of(context).insert(_overlayEntry!);
    if (mounted) {
      setState(() {});
    }
  }

  void _scheduleOverlayRebuild() {
    if (!_isOpen || _overlayEntry == null || _overlayRebuildScheduled) {
      return;
    }
    _overlayRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayRebuildScheduled = false;
      if (!mounted || !_isOpen) {
        return;
      }
      _overlayEntry?.markNeedsBuild();
    });
  }

  void _updateTriggerMetrics() {
    final triggerBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (triggerBox != null) {
      _triggerSize = triggerBox.size;
    }
  }

  RenderBox? _updateTriggerMetricsForOverlay(BuildContext overlayContext) {
    final triggerBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayState = Overlay.maybeOf(overlayContext);
    final overlayBox = overlayState?.context.findRenderObject() as RenderBox?;

    if (triggerBox != null) {
      _triggerSize = triggerBox.size;
    }
    if (triggerBox != null && overlayBox != null) {
      _triggerOffsetInOverlay = triggerBox.localToGlobal(
        Offset.zero,
        ancestor: overlayBox,
      );
    }
    return overlayBox;
  }

  void _removeOverlay({bool updateState = true}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _overlayRebuildScheduled = false;
    if (updateState && _isOpen && mounted) {
      setState(() {
        _isOpen = false;
      });
      return;
    }
    _isOpen = false;
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final overlayBox = _updateTriggerMetricsForOverlay(overlayContext);
    final mediaQuery = MediaQuery.of(overlayContext);
    final overlayWidth = overlayBox?.size.width ?? mediaQuery.size.width;
    final desiredWidth = _triggerSize.width + widget.panelExtraWidth;
    final panelWidth = desiredWidth
        .clamp(_triggerSize.width, overlayWidth)
        .toDouble();
    final overflow = (panelWidth - _triggerSize.width).clamp(0, overlayWidth);
    final horizontalOffset = switch (widget.alignment) {
      // 右对齐：面板右边缘贴 trigger 右边缘，多出的宽度向左延伸，最多延伸
      // 到 overlay 左边界（trigger 越靠右可用空间越大）。
      AppFilterPopoverAlignment.rightAlignedToTrigger =>
        -overflow.clamp(0, _triggerOffsetInOverlay.dx).toDouble(),
      // 左对齐：面板左边缘贴 trigger 左边缘，多出的宽度向右延伸；trigger 太
      // 靠右导致面板会超出 overlay 时，再把面板整体左移到刚好贴 overlay 右边。
      AppFilterPopoverAlignment.leftAlignedToTrigger => () {
        final rightSpace =
            overlayWidth - _triggerOffsetInOverlay.dx - _triggerSize.width;
        if (overflow <= rightSpace) {
          return 0.0;
        }
        return -(overflow - rightSpace).toDouble();
      }(),
    };

    final overlayHeight = overlayBox?.size.height ?? mediaQuery.size.height;
    final panelTop =
        _triggerOffsetInOverlay.dy + _triggerSize.height + _panelVerticalGap;
    final bottomMargin = mediaQuery.padding.bottom + context.appSpacing.lg;
    final safeOverlayHeight = (overlayHeight - bottomMargin)
        .clamp(1.0, overlayHeight)
        .toDouble();
    final availablePanelHeight = safeOverlayHeight - panelTop;
    final maxPanelHeight = availablePanelHeight > 0
        ? availablePanelHeight
        : safeOverlayHeight;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _removeOverlay,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(
            horizontalOffset,
            _triggerSize.height + _panelVerticalGap,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              key: widget.panelKey,
              width: panelWidth,
              constraints: BoxConstraints(maxHeight: maxPanelHeight),
              padding: EdgeInsets.all(context.appSpacing.lg),
              decoration: BoxDecoration(
                color: context.appColors.surfaceCard,
                borderRadius: context.appRadius.mdBorder,
                border: Border.all(color: context.appColors.borderSubtle),
                boxShadow: context.appShadows.panel,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      key: widget.scrollViewKey,
                      child: widget.panelBuilder(overlayContext),
                    ),
                  ),
                  if (widget.footer != null) ...[
                    SizedBox(height: context.appSpacing.lg),
                    widget.footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final highlight =
        widget.isSelected || (widget.highlightWhenOpen && _isOpen);
    final customTrigger = widget.triggerBuilder;
    return CompositedTransformTarget(
      link: _layerLink,
      child: KeyedSubtree(
        key: _triggerKey,
        child: customTrigger != null
            ? customTrigger(
                context,
                _isOpen,
                widget.enabled ? _togglePanel : () {},
              )
            : AppTextButton(
                key: widget.triggerKey,
                label: widget.triggerLabel,
                labelKey: widget.labelKey,
                icon: const Icon(Icons.filter_alt_outlined),
                trailingIcon: Icon(
                  _isOpen ? Icons.expand_less : Icons.expand_more,
                ),
                size: AppTextButtonSize.small,
                isSelected: highlight,
                onPressed: widget.enabled ? _togglePanel : null,
              ),
      ),
    );
  }
}

/// 筛选面板底栏：左侧文案 + 右侧「重置」按钮。
///
/// actor / movie 私有版逐字相同。ranking 无 footer。
class AppFilterPanelFooter extends StatelessWidget {
  const AppFilterPanelFooter({
    super.key,
    required this.isDefault,
    required this.onReset,
    this.defaultLabel = '当前使用默认筛选',
    this.activeLabel = '筛选条件已更新',
    this.resetLabel = '重置',
  });

  final bool isDefault;
  final VoidCallback? onReset;
  final String defaultLabel;
  final String activeLabel;
  final String resetLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          isDefault ? defaultLabel : activeLabel,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        AppButton(
          label: resetLabel,
          size: AppButtonSize.xSmall,
          variant: AppButtonVariant.secondary,
          onPressed: isDefault ? null : onReset,
        ),
      ],
    );
  }
}
