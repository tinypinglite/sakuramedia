import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_filter_entry_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';

/// 列表/分区通用顶栏，**桌面与移动共用一条**。
///
/// 常规态固定分成三段：
/// 1. 最左侧筛选入口（[AppFilterEntryButton]），所有筛选收口到这里；
/// 2. 中间若干不可点击的 [informationSlots]（总数、更新时间…）；
/// 3. 最右侧若干可交互的 [actionSlots]（选择、新建、查看全部…）。
///
/// **两端唯一的差别是筛选面板的容器**：桌面传 [filterPanelBuilder] 就地展开
/// 浮层，移动传 [onFilterTap] 弹底部抽屉；按钮外观、面板内容、即时生效的行为
/// 完全一致。
///
/// **两个都不传**表示这个列表没有筛选维度（如系列影片页——后端
/// `/movies/by-series` 只吃 seriesId/分页），此时左侧不渲染入口，信息槽从最左
/// 开始。只有真的无筛选才这么用；有筛选却不接入口会让这一行看起来像别的东西。
///
/// 进入多选后使用 [AppListHeader.selection] 原地改写整条顶栏，不再显示筛选入口
/// 与常规信息，避免两套上下文同时出现。
class AppListHeader extends StatelessWidget {
  const AppListHeader({
    super.key,
    this.onFilterTap,
    this.filterPanelBuilder,
    this.filterPanelFooter,
    this.filterPanelKey,
    this.filterPanelExtraWidth = 260,
    this.onFilterPanelOpened,
    this.filterIcon = Icons.tune_rounded,
    this.filterLabel,
    this.filterTooltip = '筛选',
    this.filterButtonKey,
    this.filterEnabled = true,
    this.informationSlots = const <Widget>[],
    this.actionSlots = const <Widget>[],
  }) : assert(
         onFilterTap == null || filterPanelBuilder == null,
         'onFilterTap（移动：底部抽屉）与 filterPanelBuilder（桌面：就地浮层）'
         '最多只能提供一个',
       ),
       selectionLabel = null,
       onExitSelection = null,
       selectionExitButtonKey = null,
       selectionExitTooltip = null;

  const AppListHeader.selection({
    super.key,
    required this.selectionLabel,
    required this.onExitSelection,
    this.selectionExitButtonKey,
    this.selectionExitTooltip = '退出选择',
    this.actionSlots = const <Widget>[],
  }) : onFilterTap = null,
       filterPanelBuilder = null,
       filterPanelFooter = null,
       filterPanelKey = null,
       filterPanelExtraWidth = 260,
       onFilterPanelOpened = null,
       filterIcon = Icons.tune_rounded,
       filterLabel = null,
       filterTooltip = null,
       filterButtonKey = null,
       filterEnabled = true,
       informationSlots = const <Widget>[];

  /// **移动端**筛选入口：点击弹底部抽屉。与 [filterPanelBuilder] 二选一。
  final VoidCallback? onFilterTap;

  /// **桌面端**筛选入口：点击就地展开浮层面板，内容由它构建。
  /// 面板内容应与移动抽屉里的**同一个** `XxxFilterSectionGroup`。
  final WidgetBuilder? filterPanelBuilder;

  /// 桌面浮层的 footer，通常是 `AppFilterPanelFooter`（重置在这里）。
  final Widget? filterPanelFooter;

  final Key? filterPanelKey;
  final double filterPanelExtraWidth;
  final VoidCallback? onFilterPanelOpened;

  final IconData filterIcon;

  /// 当前筛选摘要，直接长在筛选入口里（`⚙ 全部·单体 ▾`）。
  ///
  /// 它**不该**再作为只读的 [AppListHeaderInfo] 放进 [informationSlots]：
  /// 「筛了什么」和「点这里改筛选」本来就是一回事，拆成两处会让用户既看不出
  /// 图标可点、又要在两个地方拼信息。为空时退化为纯图标入口。
  final String? filterLabel;

  final String? filterTooltip;
  final Key? filterButtonKey;

  /// 筛选入口是否可点。**两端同一个开关**：榜单页在筛选元数据（来源 / 榜单）
  /// 还没加载完时传 `false`，避免点开一个空面板。外观不变——它只是暂时不响应，
  /// 不是另一种状态。
  final bool filterEnabled;

  /// 不可点击的信息节点，例如当前筛选摘要、总数、排行榜更新时间。
  final List<Widget> informationSlots;

  /// 可交互节点，例如新建、查看全部、更多、选择。
  final List<Widget> actionSlots;

  /// 多选态的计数文案，例如「已选 3 部」。
  final String? selectionLabel;
  final VoidCallback? onExitSelection;
  final Key? selectionExitButtonKey;
  final String? selectionExitTooltip;

  bool get _isSelectionMode => selectionLabel != null;

  /// 这一行有没有筛选入口。两个筛选参数都不传 = 该列表无筛选维度。
  bool get _hasFilterEntry => onFilterTap != null || filterPanelBuilder != null;

  /// 两端共用同一个 [AppFilterEntryButton] 外观，只有展开方式不同：
  /// 桌面就地浮层（[AppFilterPopover]），移动底部抽屉（[onFilterTap]）。
  Widget _buildFilterEntry(BuildContext context) {
    final panelBuilder = filterPanelBuilder;
    if (panelBuilder == null) {
      return KeyedSubtree(
        key: filterButtonKey,
        child: AppFilterEntryButton(
          icon: filterIcon,
          label: filterLabel,
          tooltip: filterTooltip,
          onTap: filterEnabled ? onFilterTap : null,
        ),
      );
    }
    return AppFilterPopover(
      triggerKey: filterButtonKey,
      triggerLabel: filterLabel ?? '',
      panelKey: filterPanelKey ?? const Key('app-filter-header-panel'),
      panelExtraWidth: filterPanelExtraWidth,
      enabled: filterEnabled,
      onOpened: onFilterPanelOpened,
      alignment: AppFilterPopoverAlignment.leftAlignedToTrigger,
      panelBuilder: panelBuilder,
      footer: filterPanelFooter,
      triggerBuilder:
          (context, isOpen, toggle) => KeyedSubtree(
            key: filterButtonKey,
            child: AppFilterEntryButton(
              icon: filterIcon,
              label: filterLabel,
              tooltip: filterTooltip,
              trailingIcon:
                  isOpen
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
              onTap: toggle,
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;
    // 无筛选维度的列表（两个筛选参数都不传）左侧不占位，信息槽从最左开始。
    final Widget? leading =
        _isSelectionMode
            ? AppIconButton(
              key: selectionExitButtonKey,
              icon: const Icon(Icons.close_rounded),
              tooltip: selectionExitTooltip,
              semanticLabel: selectionExitTooltip,
              // regular = iconSizeMd + md*2 = 44，达到 iOS HIG 的最小点按尺寸。
              size: AppIconButtonSize.regular,
              onPressed: onExitSelection,
            )
            : (_hasFilterEntry ? _buildFilterEntry(context) : null);

    return Padding(
      padding: EdgeInsets.only(top: spacing.xs),
      child: SizedBox(
        height: componentTokens.mobileTopTabHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[leading, SizedBox(width: spacing.sm)],
            Expanded(
              child: _HeaderSlotsViewport(
                informationSlots:
                    _isSelectionMode
                        ? <Widget>[
                          Text(
                            selectionLabel!,
                            key: const Key('app-list-header-selection-label'),
                            style: resolveAppTextStyle(
                              context,
                              size: AppTextSize.s14,
                              weight: AppTextWeight.medium,
                              tone: AppTextTone.primary,
                            ),
                          ),
                        ]
                        : informationSlots,
                actionSlots: actionSlots,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [AppListHeader] 的标准只读信息胶囊。
///
/// 它没有点击回调，刻意与右侧操作保持语义和视觉差异。
class AppListHeaderInfo extends StatelessWidget {
  const AppListHeaderInfo({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final foreground = context.appTextPalette.secondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        // 与 AppFilterEntryButton 同一档圆角，整条顶栏的胶囊看起来是一套。
        borderRadius: context.appRadius.smBorder,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: spacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: context.appComponentTokens.iconSizeXs,
                color: foreground,
              ),
              SizedBox(width: spacing.xs),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderSlotsViewport extends StatelessWidget {
  const _HeaderSlotsViewport({
    required this.informationSlots,
    required this.actionSlots,
  });

  final List<Widget> informationSlots;
  final List<Widget> actionSlots;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return LayoutBuilder(
      builder:
          (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: IntrinsicWidth(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      key: const Key('app-list-header-information-slots'),
                      mainAxisSize: MainAxisSize.min,
                      children: _withSpacing(informationSlots, spacing.xs),
                    ),
                    if (informationSlots.isNotEmpty && actionSlots.isNotEmpty)
                      SizedBox(width: spacing.lg),
                    Row(
                      key: const Key('app-list-header-action-slots'),
                      mainAxisSize: MainAxisSize.min,
                      children: _withSpacing(actionSlots, spacing.xs),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  List<Widget> _withSpacing(List<Widget> slots, double gap) {
    return <Widget>[
      for (var index = 0; index < slots.length; index++) ...[
        if (index > 0) SizedBox(width: gap),
        slots[index],
      ],
    ];
  }
}
