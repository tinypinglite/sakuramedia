import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_surface.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_fullscreen.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';

/// 弹出菜单的一项。
///
/// [icon] 为 `null` 时只渲染文字（卡片右键菜单）；[subtitle] 用于补充说明；
/// [tone] 沿用应用文字色调，危险操作传 [AppTextTone.error]；[key] 用于沿用
/// 既有测试锚点。菜单项之间靠固定间距分项，没有分隔线。
class AppMenuItem<T> {
  const AppMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.subtitle,
    this.tone = AppTextTone.primary,
    this.enabled = true,
    this.visible = true,
    this.key,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? subtitle;
  final AppTextTone tone;
  final bool enabled;
  final bool visible;
  final Key? key;
}

/// 决定 [showAppActionMenu] 用哪种壳显示。
///
/// 形态由**触发方式**决定，不按平台：长按 / 右键这类上下文入口用 [popup]
/// （锚定在按压点，即移动端的「右键菜单」）；「更多」按钮触发的动作列表用
/// [bottomDrawer]（可选标题 + 独立「取消」行）。国内主流 App 的惯例如此。
enum AppMenuPresentation { popup, bottomDrawer }

/// 全应用唯一的右键 / 长按菜单壳。
///
/// 负责：过滤 [AppMenuItem.visible]、定位、统一表面样式与项渲染、底部操作表
/// （可选标题 + 独立「取消」行）、全屏图片下的抽屉宿主。
///
/// 锚定弹层使用 `AppGlassSurface` 的统一玻璃材质，并按桌面 / 移动
/// 分别采用紧凑密度；不显示源内容预览、抬升动画或全屏压暗。
/// 调用方保留自己的 action 枚举、items 组装与派发 `switch`。
Future<T?> showAppActionMenu<T>({
  required BuildContext context,
  required List<AppMenuItem<T>> items,
  Offset? globalPosition,
  AppMenuPresentation presentation = AppMenuPresentation.popup,
  Key? drawerKey,
  String? title,
  String? titleSubtitle,
  bool showCancelRow = true,
}) {
  final visibleItems = items.where((item) => item.visible).toList();
  if (visibleItems.isEmpty) {
    return Future<T?>.value(null);
  }

  if (presentation == AppMenuPresentation.bottomDrawer) {
    return _showDrawerMenu(
      context: context,
      items: visibleItems,
      drawerKey: drawerKey,
      title: title,
      titleSubtitle: titleSubtitle,
      showCancelRow: showCancelRow,
    );
  }
  return _showPopupMenu(
    context: context,
    items: visibleItems,
    globalPosition: globalPosition,
  );
}

const double _drawerItemMinHeight = 52;
const double _drawerItemWithSubtitleHeight = 68;
const double _cancelGapHeight = 8;
const double _drawerTopSpacing = 20;
const double _drawerTitleHeight = 48;

class _AppContextMenuMetrics {
  const _AppContextMenuMetrics({
    required this.minWidth,
    required this.maxWidth,
    required this.outerPadding,
    required this.itemHorizontalPadding,
    required this.itemVerticalPadding,
    required this.rowHeight,
    required this.rowWithSubtitleHeight,
    required this.iconSize,
    required this.iconGap,
    required this.anchorGap,
    required this.radius,
    required this.itemRadius,
    required this.titleSize,
    required this.subtitleSize,
  });

  static const desktop = _AppContextMenuMetrics(
    minWidth: 160,
    maxWidth: 240,
    outerPadding: 4,
    itemHorizontalPadding: 10,
    itemVerticalPadding: 4,
    rowHeight: 30,
    rowWithSubtitleHeight: 44,
    iconSize: 16,
    iconGap: 8,
    anchorGap: 6,
    radius: 18,
    itemRadius: 10,
    titleSize: AppTextSize.s14,
    subtitleSize: AppTextSize.s12,
  );

  static const mobile = _AppContextMenuMetrics(
    minWidth: 180,
    maxWidth: 260,
    outerPadding: 6,
    itemHorizontalPadding: 12,
    itemVerticalPadding: 6,
    rowHeight: 38,
    rowWithSubtitleHeight: 50,
    iconSize: 18,
    iconGap: 8,
    anchorGap: 8,
    radius: 24,
    itemRadius: 14,
    titleSize: AppTextSize.s14,
    subtitleSize: AppTextSize.s12,
  );

  factory _AppContextMenuMetrics.of(BuildContext context) {
    return AppPlatformScope.maybeOf(context) == AppPlatform.mobile
        ? mobile
        : desktop;
  }

  final double minWidth;
  final double maxWidth;
  final double outerPadding;
  final double itemHorizontalPadding;
  final double itemVerticalPadding;
  final double rowHeight;
  final double rowWithSubtitleHeight;
  final double iconSize;
  final double iconGap;
  final double anchorGap;
  final double radius;
  final double itemRadius;
  final AppTextSize titleSize;
  final AppTextSize subtitleSize;
}

Future<T?> _showPopupMenu<T>({
  required BuildContext context,
  required List<AppMenuItem<T>> items,
  required Offset? globalPosition,
}) {
  if (globalPosition == null) {
    return Future<T?>.value(null);
  }

  final navigator = Navigator.of(context, rootNavigator: true);
  final overlay = navigator.overlay!.context.findRenderObject() as RenderBox;
  final metrics = _AppContextMenuMetrics.of(context);
  return navigator.push<T>(
    _AppContextMenuRoute<T>(
      anchor: overlay.globalToLocal(globalPosition),
      items: items,
      metrics: metrics,
      width: _resolveContextMenuWidth(context, items, metrics),
      barrierLabel: MaterialLocalizations.of(context).menuDismissLabel,
    ),
  );
}

double _resolveContextMenuWidth<T>(
  BuildContext context,
  List<AppMenuItem<T>> items,
  _AppContextMenuMetrics metrics,
) {
  final fontFamily = resolveAppFontFamily(context);
  final titleStyle = resolveAppTextStyle(
    context,
    size: metrics.titleSize,
    tone: AppTextTone.primary,
  ).copyWith(fontFamily: fontFamily);
  final subtitleStyle = resolveAppTextStyle(
    context,
    size: metrics.subtitleSize,
    tone: AppTextTone.muted,
  ).copyWith(fontFamily: fontFamily);
  final textScaler = MediaQuery.textScalerOf(context);
  final textDirection = Directionality.of(context);
  var widestRow = 0.0;
  for (final item in items) {
    final titleWidth = _measureContextMenuText(
      item.label,
      titleStyle,
      textScaler,
      textDirection,
    );
    final subtitleWidth = item.subtitle == null
        ? 0.0
        : _measureContextMenuText(
            item.subtitle!,
            subtitleStyle,
            textScaler,
            textDirection,
          );
    final iconWidth = item.icon == null
        ? 0.0
        : metrics.iconSize + metrics.iconGap;
    final rowWidth =
        math.max(titleWidth, subtitleWidth) +
        iconWidth +
        metrics.itemHorizontalPadding * 2 +
        8;
    widestRow = math.max(widestRow, rowWidth);
  }
  return (widestRow + metrics.outerPadding * 2)
      .clamp(metrics.minWidth, metrics.maxWidth)
      .toDouble();
}

double _measureContextMenuText(
  String text,
  TextStyle style,
  TextScaler textScaler,
  TextDirection textDirection,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textScaler: textScaler,
    textDirection: textDirection,
  )..layout();
  final width = painter.width.ceilToDouble();
  painter.dispose();
  return width;
}

class _AppContextMenuRoute<T> extends PopupRoute<T> {
  _AppContextMenuRoute({
    required this.anchor,
    required this.items,
    required this.metrics,
    required this.width,
    required this.barrierLabel,
  }) : super(requestFocus: true);

  final Offset anchor;
  final List<AppMenuItem<T>> items;
  final _AppContextMenuMetrics metrics;
  final double width;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 100);

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  final String barrierLabel;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _AppContextMenuPage<T>(
      anchor: anchor,
      items: items,
      metrics: metrics,
      width: width,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(animation.value);
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.96 + 0.04 * t, child: child!),
        );
      },
    );
  }
}

class _AppContextMenuPage<T> extends StatelessWidget {
  const _AppContextMenuPage({
    required this.anchor,
    required this.items,
    required this.metrics,
    required this.width,
  });

  final Offset anchor;
  final List<AppMenuItem<T>> items;
  final _AppContextMenuMetrics metrics;
  final double width;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxMenuHeight = math.max(
          80.0,
          constraints.maxHeight - padding.vertical - 16,
        );
        return CustomSingleChildLayout(
          delegate: _AppContextMenuLayout(
            anchor: anchor,
            padding: padding,
            gap: metrics.anchorGap,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxMenuHeight),
            child: _AppContextMenuPanel<T>(
              items: items,
              metrics: metrics,
              width: width,
            ),
          ),
        );
      },
    );
  }
}

class _AppContextMenuPanel<T> extends StatelessWidget {
  const _AppContextMenuPanel({
    required this.items,
    required this.metrics,
    required this.width,
  });

  final List<AppMenuItem<T>> items;
  final _AppContextMenuMetrics metrics;
  final double width;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = context.appColors.borderStrong;
    final firstEnabledIndex = items.indexWhere((item) => item.enabled);

    return Semantics(
      role: SemanticsRole.menu,
      container: true,
      explicitChildNodes: true,
      child: AppGlassSurface(
        width: width,
        borderRadius: BorderRadius.circular(metrics.radius),
        padding: EdgeInsets.zero,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(metrics.radius),
              side: BorderSide(color: borderColor, width: 0.5),
            ),
          ),
          child: ColoredBox(
            color:
                (isDark
                        ? context.appColors.surfaceElevated
                        : context.appColors.surfaceCard)
                    .withValues(alpha: isDark ? 0.38 : 0.30),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(metrics.outerPadding),
              child: FocusTraversalGroup(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (var index = 0; index < items.length; index++)
                      _AppContextMenuActionRow<T>(
                        key: items[index].key,
                        item: items[index],
                        metrics: metrics,
                        autofocus: index == firstEnabledIndex,
                        onSelected: () =>
                            Navigator.of(context).pop<T>(items[index].value),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppContextMenuActionRow<T> extends StatefulWidget {
  const _AppContextMenuActionRow({
    super.key,
    required this.item,
    required this.metrics,
    required this.autofocus,
    required this.onSelected,
  });

  final AppMenuItem<T> item;
  final _AppContextMenuMetrics metrics;
  final bool autofocus;
  final VoidCallback onSelected;

  @override
  State<_AppContextMenuActionRow<T>> createState() =>
      _AppContextMenuActionRowState<T>();
}

class _AppContextMenuActionRowState<T>
    extends State<_AppContextMenuActionRow<T>> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (!mounted || _hovered == value) {
      return;
    }
    setState(() => _hovered = value);
  }

  void _setFocused(bool value) {
    if (!mounted || _focused == value) {
      return;
    }
    setState(() => _focused = value);
  }

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) {
      return;
    }
    setState(() => _pressed = value);
  }

  void _activate() {
    if (widget.item.enabled) {
      widget.onSelected();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final metrics = widget.metrics;
    final enabled = item.enabled;
    final danger = enabled && item.tone == AppTextTone.error;
    final titleTone = enabled ? item.tone : AppTextTone.muted;
    final iconTone = danger
        ? AppTextTone.error
        : (enabled ? AppTextTone.secondary : AppTextTone.muted);
    final fontFamily = resolveAppFontFamily(context);
    final highlightColor = danger
        ? context.appTextPalette.error.withValues(alpha: 0.12)
        : context.appColors.divider;
    final pressedBackground = danger
        ? highlightColor.withValues(
            alpha: math.min(1.0, highlightColor.a + 0.04),
          )
        : context.appColors.borderSubtle;
    final background = _pressed
        ? pressedBackground
        : (_hovered || _focused ? highlightColor : Colors.transparent);
    final subtitle = item.subtitle;
    final icon = item.icon;

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: item.label,
      value: subtitle,
      onTap: enabled ? _activate : null,
      child: ExcludeSemantics(
        child: AbsorbPointer(
          absorbing: !enabled,
          child: FocusableActionDetector(
            enabled: enabled,
            autofocus: widget.autofocus,
            includeFocusSemantics: false,
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  _activate();
                  return null;
                },
              ),
            },
            onShowHoverHighlight: _setHovered,
            onShowFocusHighlight: _setFocused,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTapDown: enabled ? (_) => _setPressed(true) : null,
              onTapUp: enabled ? (_) => _setPressed(false) : null,
              onTapCancel: enabled ? () => _setPressed(false) : null,
              onTap: enabled ? _activate : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 110),
                curve: Curves.easeOutCubic,
                constraints: BoxConstraints(
                  minHeight: subtitle == null
                      ? metrics.rowHeight
                      : metrics.rowWithSubtitleHeight,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.itemHorizontalPadding,
                  vertical: metrics.itemVerticalPadding,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(metrics.itemRadius),
                ),
                child: Row(
                  children: <Widget>[
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: metrics.iconSize,
                        color: resolveAppTextToneColor(context, iconTone),
                      ),
                      SizedBox(width: metrics.iconGap),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: resolveAppTextStyle(
                              context,
                              size: metrics.titleSize,
                              tone: titleTone,
                            ).copyWith(fontFamily: fontFamily),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: resolveAppTextStyle(
                                context,
                                size: metrics.subtitleSize,
                                tone: AppTextTone.muted,
                              ).copyWith(fontFamily: fontFamily),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppContextMenuLayout extends SingleChildLayoutDelegate {
  const _AppContextMenuLayout({
    required this.anchor,
    required this.padding,
    required this.gap,
  });

  final Offset anchor;
  final EdgeInsets padding;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final safeLeft = padding.left + 8;
    final safeRight = size.width - padding.right - 8;
    final safeTop = padding.top + 8;
    final safeBottom = size.height - padding.bottom - 8;
    final maxLeft = math.max(safeLeft, safeRight - childSize.width);
    final x = (anchor.dx - childSize.width / 2)
        .clamp(safeLeft, maxLeft)
        .toDouble();
    final maxTop = math.max(safeTop, safeBottom - childSize.height);
    final below = anchor.dy + gap;
    final above = anchor.dy - gap - childSize.height;
    final double y;
    if (below + childSize.height <= safeBottom) {
      y = below;
    } else if (above >= safeTop) {
      y = above;
    } else {
      y = (anchor.dy - childSize.height / 2).clamp(safeTop, maxTop).toDouble();
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_AppContextMenuLayout oldDelegate) {
    return anchor != oldDelegate.anchor ||
        padding != oldDelegate.padding ||
        gap != oldDelegate.gap;
  }
}

Future<T?> _showDrawerMenu<T>({
  required BuildContext context,
  required List<AppMenuItem<T>> items,
  required Key? drawerKey,
  required String? title,
  required String? titleSubtitle,
  required bool showCancelRow,
}) {
  final screenHeight = MediaQuery.sizeOf(context).height;
  final itemsHeight = items.fold<double>(0, (total, item) {
    return total +
        (item.subtitle == null
            ? _drawerItemMinHeight
            : _drawerItemWithSubtitleHeight);
  });
  final hasHeader = title != null || titleSubtitle != null;
  final headerHeight = hasHeader
      ? _drawerTitleHeight + (titleSubtitle == null ? 0 : 18)
      : 0;
  final estimatedHeight =
      _drawerTopSpacing +
      headerHeight +
      itemsHeight +
      (showCancelRow ? _cancelGapHeight + _drawerItemMinHeight : 0);
  final heightFactor = (estimatedHeight / screenHeight).clamp(0.24, 0.92);

  final inlineFullscreenDrawer = AppImageFullscreenHost.showBottomDrawer<T>(
    context: context,
    drawerKey: drawerKey,
    heightFactor: heightFactor,
    ignoreTopSafeArea: true,
    contentPadding: EdgeInsets.zero,
    builder: (drawerContext, close) => _AppActionMenuDrawer<T>(
      items: items,
      title: title,
      titleSubtitle: titleSubtitle,
      showCancelRow: showCancelRow,
      onSelected: close,
    ),
  );
  if (inlineFullscreenDrawer != null) {
    return inlineFullscreenDrawer;
  }

  return showAppBottomDrawer<T>(
    context: context,
    drawerKey: drawerKey,
    maxHeightFactor: heightFactor,
    ignoreTopSafeArea: true,
    contentPadding: EdgeInsets.zero,
    builder: (drawerContext) => _AppActionMenuDrawer<T>(
      items: items,
      title: title,
      titleSubtitle: titleSubtitle,
      showCancelRow: showCancelRow,
      onSelected: (value) => Navigator.of(drawerContext).pop(value),
    ),
  );
}

class _AppActionMenuDrawer<T> extends StatelessWidget {
  const _AppActionMenuDrawer({
    required this.items,
    required this.title,
    required this.titleSubtitle,
    required this.showCancelRow,
    required this.onSelected,
  });

  final List<AppMenuItem<T>> items;
  final String? title;
  final String? titleSubtitle;
  final bool showCancelRow;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final componentTokens = Theme.of(context).appComponentTokens;
    final title = this.title;
    final titleSubtitle = this.titleSubtitle;

    // 高度估算偏低或系统放大字体时，靠滚动兜底而不是溢出。
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.lg,
              spacing.lg,
              spacing.lg,
              (title == null && titleSubtitle == null)
                  ? spacing.xs
                  : spacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  Text(
                    title,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s16,
                      weight: AppTextWeight.semibold,
                      tone: AppTextTone.primary,
                    ),
                  ),
                if (titleSubtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    titleSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final item in items)
            _AppDrawerRow<T>(
              item: item,
              iconSize: componentTokens.iconSizeSm,
              onSelected: onSelected,
            ),
          if (showCancelRow) ...[
            SizedBox(
              height: _cancelGapHeight,
              child: ColoredBox(color: context.appColors.surfacePage),
            ),
            _AppDrawerCancelRow(onTap: () => onSelected(null)),
          ],
        ],
      ),
    );
  }
}

class _AppDrawerRow<T> extends StatelessWidget {
  const _AppDrawerRow({
    required this.item,
    required this.iconSize,
    required this.onSelected,
  });

  final AppMenuItem<T> item;
  final double iconSize;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return InkWell(
      key: item.key,
      onTap: item.enabled ? () => onSelected(item.value) : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _drawerItemMinHeight),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.md,
          ),
          child: _AppMenuRow<T>(
            item: item,
            iconSize: iconSize,
            labelSize: AppTextSize.s12,
          ),
        ),
      ),
    );
  }
}

class _AppDrawerCancelRow extends StatelessWidget {
  const _AppDrawerCancelRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _drawerItemMinHeight),
        child: Center(
          child: Text(
            l10n.commonCancel,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppMenuRow<T> extends StatelessWidget {
  const _AppMenuRow({
    required this.item,
    required this.iconSize,
    required this.labelSize,
  });

  final AppMenuItem<T> item;
  final double iconSize;
  final AppTextSize labelSize;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final resolvedTone = item.enabled ? item.tone : AppTextTone.muted;
    final icon = item.icon;
    final isDanger = item.enabled && item.tone == AppTextTone.error;
    final iconColor = icon == null
        ? null
        : resolveAppTextToneColor(
            context,
            isDanger
                ? AppTextTone.error
                : (item.enabled ? AppTextTone.secondary : AppTextTone.muted),
          );

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize, color: iconColor),
          SizedBox(width: spacing.sm),
        ],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: labelSize,
                  tone: resolvedTone,
                ),
              ),
              if (item.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  item.subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
