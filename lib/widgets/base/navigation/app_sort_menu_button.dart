import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/shared/data/sort_direction.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_popover.dart';

/// 列表的独立排序入口。
///
/// 排序是视图偏好，不属于筛选条件：桌面在顶栏右侧展开锚定浮层，移动端用底部
/// 抽屉。两端按钮长得一样（桌面带摘要，移动仅图标），排序内容都由内部
/// [AppGlassSortSection] 渲染。桌面浮层选中即应用并关闭；移动抽屉只即时应用，
/// 选中态留在抽屉内继续可见，由用户点遮罩或下拉关闭。
///
/// 字段类型由调用方提供；方向使用跨 feature 共享的 [SortDirection]，本组件不
/// 依赖具体业务域的排序枚举。
class AppSortMenuButton<F> extends StatefulWidget {
  const AppSortMenuButton({
    super.key,
    required this.fields,
    required this.selectedField,
    required this.fieldLabelBuilder,
    required this.onFieldChanged,
    required this.selectedDirection,
    required this.onDirectionChanged,
    this.directionVisibleWhen,
    this.allowDefaultOption = false,
    this.defaultOptionLabel,
    this.triggerLabel,
    this.useDrawer = false,
    this.glassGrouped = false,
    this.iconOnly = false,
    this.enabled = true,
    this.triggerKey,
    this.panelKey,
    this.drawerKey,
    this.fieldKeyBuilder,
    this.directionKeyBuilder,
    this.defaultOptionKey,
    this.fieldControlKey,
    this.directionControlKey,
    this.closeOnSelect = true,
    this.tooltip,
  });

  final List<F> fields;
  final F? selectedField;
  final String Function(F field) fieldLabelBuilder;
  final ValueChanged<F?> onFieldChanged;

  final SortDirection selectedDirection;
  final ValueChanged<SortDirection> onDirectionChanged;

  /// 方向分节是否显示；参数是当前字段。为空时始终显示。
  final bool Function(F? field)? directionVisibleWhen;

  /// 是否在字段前渲染「默认」选项；选中时回调 `null`。
  final bool allowDefaultOption;
  final String? defaultOptionLabel;

  /// 完全覆盖自动生成的摘要（一般不需要）。
  final String? triggerLabel;

  /// 移动端传 `true`，点击弹底部抽屉。
  final bool useDrawer;

  /// 桌面玻璃入口由调用方放进 [AppGlassHeaderGroup] 时置为 true，避免再包一层
  /// 玻璃分组。
  final bool glassGrouped;

  /// 移动端抽屉入口只显示图标；只在 [useDrawer] 时生效。
  final bool iconOnly;

  /// 为 false 时入口不可点（例如女优搜索中按相关度排序）。
  final bool enabled;

  final Key? triggerKey;
  final Key? panelKey;
  final Key? drawerKey;

  final Key? Function(F field)? fieldKeyBuilder;
  final Key? Function(SortDirection direction)? directionKeyBuilder;
  final Key? defaultOptionKey;
  final Key? fieldControlKey;
  final Key? directionControlKey;

  /// 桌面浮层选中后是否自动关闭；移动抽屉始终即时应用且不自动关闭。
  final bool closeOnSelect;
  final String? tooltip;

  @override
  State<AppSortMenuButton<F>> createState() => _AppSortMenuButtonState<F>();
}

class _AppSortMenuButtonState<F> extends State<AppSortMenuButton<F>> {
  String _label(AppLocalizations l10n) {
    final override = widget.triggerLabel;
    if (override != null) {
      return override;
    }
    final field = widget.selectedField;
    if (field == null) {
      return widget.defaultOptionLabel ?? l10n.baseSortDefault;
    }
    final fieldLabel = widget.fieldLabelBuilder(field);
    final showArrow = widget.directionVisibleWhen?.call(field) ?? true;
    return showArrow
        ? '$fieldLabel ${widget.selectedDirection.symbol}'
        : fieldLabel;
  }

  Future<void> _showDrawer(BuildContext context) {
    return showAppBottomDrawer<void>(
      context: context,
      drawerKey: widget.drawerKey ?? const Key('app-sort-drawer'),
      maxHeightFactor: 0.75,
      builder: (_) => _AppSortDrawer<F>(
        config: widget,
        onFieldChanged: _applyDrawerField,
        onDirectionChanged: _applyDrawerDirection,
      ),
    );
  }

  void _applyDrawerField(F? value) {
    widget.onFieldChanged(value);
  }

  void _applyDrawerDirection(SortDirection value) {
    widget.onDirectionChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final tooltip =
        widget.tooltip ?? '${l10n.baseSortTooltip} · ${_label(l10n)}';
    if (widget.useDrawer) {
      if (widget.iconOnly) {
        return AppGlassIconButton(
          key: widget.triggerKey,
          tooltip: tooltip,
          semanticLabel: tooltip,
          icon: Icons.swap_vert_rounded,
          onPressed: widget.enabled ? () => _showDrawer(context) : null,
        );
      }
      return AppGlassHeaderButton(
        key: widget.triggerKey,
        icon: Icons.swap_vert_rounded,
        label: _label(l10n),
        trailingIcon: Icons.expand_more_rounded,
        tooltip: tooltip,
        enabled: widget.enabled,
        onTap: widget.enabled ? () => _showDrawer(context) : () {},
      );
    }
    return AppGlassPopover(
      panelKey: widget.panelKey ?? const Key('app-sort-panel'),
      triggerBuilder: (context, toggle) {
        final trigger = AppGlassHeaderButton(
          key: widget.triggerKey,
          icon: Icons.swap_vert_rounded,
          label: _label(l10n),
          trailingIcon: Icons.expand_more_rounded,
          tooltip: tooltip,
          enabled: widget.enabled,
          onTap: widget.enabled ? toggle : () {},
        );
        return widget.glassGrouped
            ? trigger
            : AppGlassHeaderGroup(children: <Widget>[trigger]);
      },
      contentBuilder: (context, close) => AppGlassSortSection<F>(
        fields: widget.fields,
        selectedField: widget.selectedField,
        fieldLabelBuilder: widget.fieldLabelBuilder,
        onFieldChanged: (value) {
          widget.onFieldChanged(value);
          if (widget.closeOnSelect) {
            close();
          }
        },
        selectedDirection: widget.selectedDirection,
        onDirectionChanged: (value) {
          widget.onDirectionChanged(value);
          if (widget.closeOnSelect) {
            close();
          }
        },
        directionVisibleWhen: widget.directionVisibleWhen,
        allowDefaultOption: widget.allowDefaultOption,
        defaultOptionLabel: widget.defaultOptionLabel,
        fieldKeyBuilder: widget.fieldKeyBuilder,
        directionKeyBuilder: widget.directionKeyBuilder,
        defaultOptionKey: widget.defaultOptionKey,
        fieldControlKey: widget.fieldControlKey,
        directionControlKey: widget.directionControlKey,
      ),
    );
  }
}

class _AppSortDrawer<F> extends StatefulWidget {
  const _AppSortDrawer({
    required this.config,
    required this.onFieldChanged,
    required this.onDirectionChanged,
  });

  final AppSortMenuButton<F> config;
  final ValueChanged<F?> onFieldChanged;
  final ValueChanged<SortDirection> onDirectionChanged;

  @override
  State<_AppSortDrawer<F>> createState() => _AppSortDrawerState<F>();
}

class _AppSortDrawerState<F> extends State<_AppSortDrawer<F>> {
  late F? _selectedField = widget.config.selectedField;
  late SortDirection _selectedDirection = widget.config.selectedDirection;

  void _applyField(F? value) {
    setState(() => _selectedField = value);
    widget.onFieldChanged(value);
  }

  void _applyDirection(SortDirection value) {
    setState(() => _selectedDirection = value);
    widget.onDirectionChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return AppMobileFilterDrawerScaffold(
      child: AppGlassSortSection<F>(
        fields: config.fields,
        selectedField: _selectedField,
        fieldLabelBuilder: config.fieldLabelBuilder,
        onFieldChanged: _applyField,
        selectedDirection: _selectedDirection,
        onDirectionChanged: _applyDirection,
        directionVisibleWhen: config.directionVisibleWhen,
        allowDefaultOption: config.allowDefaultOption,
        defaultOptionLabel: config.defaultOptionLabel,
        fieldKeyBuilder: config.fieldKeyBuilder,
        directionKeyBuilder: config.directionKeyBuilder,
        defaultOptionKey: config.defaultOptionKey,
        fieldControlKey: config.fieldControlKey,
        directionControlKey: config.directionControlKey,
      ),
    );
  }
}
