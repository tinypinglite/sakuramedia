import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/overlays/app_anchored_popover.dart';

export 'package:sakuramedia/widgets/base/overlays/app_anchored_popover.dart'
    show AppPopoverController;

const double _panelVerticalGap = 8;

/// 通用「触发按钮 + 展开浮层面板」外壳（筛选场景）。
///
/// actor / movie / ranking 三个 FilterToolbar 的浮层骨架
/// (LayerLink / OverlayEntry / CompositedTransformFollower /
/// GestureDetector 遮罩 / 面板 Container + panel) 逐行雷同,
/// 由 [AppAnchoredPopover] 封死。本组件只保留筛选面板的宽度、滚动和 footer
/// 约定。调用方只提供:
///   - trigger 文案 / 高亮语义 / 面板宽度增量;
///   - 面板 body(`panelBuilder`);
///   - 可选 footer(通常用 [AppFilterPanelFooter])。
///
/// 面板内容一律包在 `Flexible(SingleChildScrollView)` 里,
/// 保证矮窗口不溢出。footer(若有)在滚动区之外。
class AppFilterPopover extends StatelessWidget {
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
    this.controller,
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

  /// 需要在面板内完成“应用并关闭”时使用。
  final AppPopoverController? controller;

  @override
  Widget build(BuildContext context) {
    return AppAnchoredPopover(
      placement: alignment == AppFilterPopoverAlignment.rightAlignedToTrigger
          ? AppPopoverPlacement.belowEnd
          : AppPopoverPlacement.belowStart,
      gap: _panelVerticalGap,
      enabled: enabled,
      onOpened: onOpened,
      controller: controller,
      initialTriggerSize: initialTriggerSize,
      panelWidthBuilder: (overlayContext, triggerWidth, overlayWidth) =>
          (triggerWidth + panelExtraWidth)
              .clamp(triggerWidth, overlayWidth)
              .toDouble(),
      triggerBuilder: (context, isOpen, toggle) {
        final highlight = isSelected || (highlightWhenOpen && isOpen);
        final customTrigger = triggerBuilder;
        if (customTrigger != null) {
          return TooltipVisibility(
            visible: !isOpen,
            child: customTrigger(context, isOpen, toggle),
          );
        }
        return TooltipVisibility(
          visible: !isOpen,
          child: AppTextButton(
            key: triggerKey,
            label: triggerLabel,
            labelKey: labelKey,
            icon: const Icon(Icons.filter_alt_outlined),
            trailingIcon: Icon(isOpen ? Icons.expand_less : Icons.expand_more),
            size: AppTextButtonSize.small,
            isSelected: highlight,
            onPressed: enabled ? toggle : null,
          ),
        );
      },
      panelBuilder: (overlayContext, layout, _) => Material(
        color: Colors.transparent,
        child: Container(
          key: panelKey,
          width: layout.width,
          constraints: BoxConstraints(
            maxHeight: layout.maxHeight ?? double.infinity,
          ),
          padding: EdgeInsets.all(overlayContext.appSpacing.lg),
          decoration: BoxDecoration(
            color: overlayContext.appColors.surfaceCard,
            borderRadius: overlayContext.appRadius.mdBorder,
            border: Border.all(color: overlayContext.appColors.borderSubtle),
            boxShadow: overlayContext.appShadows.panel,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  key: scrollViewKey,
                  child: panelBuilder(overlayContext),
                ),
              ),
              if (footer != null) ...[
                SizedBox(height: overlayContext.appSpacing.lg),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum AppFilterPopoverAlignment { rightAlignedToTrigger, leftAlignedToTrigger }

/// 筛选面板底栏：左侧文案 + 右侧「重置」按钮。
///
/// actor / movie 私有版逐字相同。ranking 无 footer。
class AppFilterPanelFooter extends StatelessWidget {
  const AppFilterPanelFooter({
    super.key,
    required this.isDefault,
    required this.onReset,
    this.defaultLabel,
    this.activeLabel,
    this.resetLabel,
  });

  final bool isDefault;
  final VoidCallback? onReset;
  final String? defaultLabel;
  final String? activeLabel;
  final String? resetLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          isDefault
              ? (defaultLabel ?? l10n.baseFilterUsingDefault)
              : (activeLabel ?? l10n.baseFilterUpdated),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        AppButton(
          label: resetLabel ?? l10n.baseFilterReset,
          size: AppButtonSize.xSmall,
          variant: AppButtonVariant.secondary,
          onPressed: isDefault ? null : onReset,
        ),
      ],
    );
  }
}
