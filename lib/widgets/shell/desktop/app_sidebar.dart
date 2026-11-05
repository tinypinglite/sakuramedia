import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/features/activity/presentation/providers/notification_center_provider.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/shell/desktop/sidebar_appearance_menu.dart';
import 'package:sakuramedia/widgets/shell/desktop/sidebar_version_footer.dart';
import 'package:sakuramedia/widgets/shell/window/app_window_drag_area.dart';

class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.currentPath,
    required this.navGroups,
  });

  final String currentPath;
  final List<AppNavGroup> navGroups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompact = ref.watch(appShellSidebarCollapsedProvider);
    final sidebarTokens = context.appSidebarTokens;
    final appColors = context.appColors;
    final useDesktopSidebarGlass = _useDesktopSidebarGlass;
    final glassTint = defaultTargetPlatform == TargetPlatform.windows
        ? appColors.windowsSidebarGlassTint
        : appColors.desktopSidebarGlassTint;
    final width = isCompact
        ? sidebarTokens.collapsedWidth
        : sidebarTokens.expandedWidth;

    return AnimatedContainer(
      key: const Key('desktop-shell-sidebar'),
      duration: const Duration(milliseconds: 180),
      width: width,
      clipBehavior: Clip.hardEdge,
      // 收起态宽度为 0：装饰渐隐为透明、内容整体卸载，避免残留边线
      // 和不可见的可点击区域。
      decoration: isCompact
          ? const BoxDecoration(color: Colors.transparent)
          : BoxDecoration(
              color: useDesktopSidebarGlass
                  ? glassTint
                  : appColors.sidebarBackground,
              border: Border(
                right: BorderSide(
                  color: useDesktopSidebarGlass
                      ? appColors.borderSubtle.fadedBy(0.68)
                      : appColors.borderSubtle,
                ),
              ),
              boxShadow: useDesktopSidebarGlass
                  ? const []
                  : context.appShadows.panel,
            ),
      // 展开动画期间容器比侧栏窄，内容按固定展开宽度布局、由容器裁剪
      // 滑入，避免窄约束下溢出；完全收起后内容 offstage（不绘制、不可
      // 点、不参与命中与语义），状态保留以便展开时原位恢复。
      child: Offstage(
        offstage: isCompact,
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: sidebarTokens.expandedWidth,
          maxWidth: sidebarTokens.expandedWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: const Key('sidebar-header'),
                height: context.appComponentTokens.desktopTitleBarHeight,
                // macOS 下这是窗口拖拽区；红绿灯垂直居中于 header，
                // 收起/展开按钮由壳层固定渲染在红绿灯右侧，不在
                // 侧栏内部。
                child: defaultTargetPlatform == TargetPlatform.macOS
                    ? const AppWindowDragArea(
                        child: ColoredBox(color: Colors.transparent),
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: _SidebarNavScrollArea(
                  horizontalPadding: context.appSpacing.sm,
                  fadeColor: useDesktopSidebarGlass
                      ? glassTint
                      : appColors.sidebarBackground,
                  children: _buildNavChildren(context),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(context.appSpacing.sm),
                child: _SidebarAccountCard(
                  onLogout: () {
                    context.logOut();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildNavChildren(BuildContext context) {
    final children = <Widget>[];
    String? previousSection;
    for (final group in navGroups) {
      final section = group.sectionLabel;
      if (section != null && section != previousSection) {
        children.add(_SidebarSectionHeader(label: section));
      }
      previousSection = section;
      children.add(
        Padding(
          padding: EdgeInsets.only(bottom: context.appSpacing.xs),
          child: AppSidebarGroup(group: group, currentPath: currentPath),
        ),
      );
    }
    return children;
  }
}

class _SidebarAccountCard extends StatelessWidget {
  const _SidebarAccountCard({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonFill = colors.surfaceCard.withValues(
      alpha: isDark ? 0.06 : 0.34,
    );
    final buttonBorder = colors.borderSubtle.fadedBy(isDark ? 0.75 : 0.55);
    final cardFill = colors.surfaceCard.withValues(
      alpha: isDark ? 0.055 : 0.34,
    );

    return Container(
      key: const Key('sidebar-account-card'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 88),
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        borderRadius: context.appRadius.lgBorder,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cardFill,
            cardFill.withValues(alpha: cardFill.a * 0.55),
          ],
        ),
        border: Border.all(
          color: colors.borderSubtle.fadedBy(isDark ? 0.72 : 0.50),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                key: const Key('sidebar-account-avatar'),
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                child: Text(
                  'S',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.medium,
                  ).copyWith(color: Theme.of(context).colorScheme.onPrimary),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.appTitle,
                      key: const Key('sidebar-account-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: AppTextWeight.medium,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: context.appTextPalette.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: spacing.xs),
                        Flexible(
                          child: Text(
                            l10n.shellSignedIn,
                            key: const Key('sidebar-account-status'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: resolveAppTextStyle(
                              context,
                              size: AppTextSize.s10,
                              tone: AppTextTone.tertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.xs),
              const SidebarAppearanceMenu(),
            ],
          ),
          Row(
            children: <Widget>[
              const Expanded(child: SidebarVersionFooter()),
              SizedBox(width: spacing.xs),
              AppIconButton(
                key: const Key('sidebar-logout-button'),
                icon: const Icon(Icons.logout_rounded),
                tooltip: l10n.shellLogout,
                semanticLabel: l10n.shellLogout,
                iconColor: context.appTextPalette.tertiary,
                backgroundColor: buttonFill,
                borderColor: buttonBorder,
                borderRadius: context.appRadius.smBorder,
                onPressed: onLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SidebarSectionHeader extends StatelessWidget {
  const _SidebarSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('sidebar-section-$label'),
      padding: EdgeInsets.only(
        top: context.appSpacing.md,
        bottom: context.appSpacing.xs,
        left: context.appSpacing.md,
        right: context.appSpacing.md,
      ),
      child: Text(
        label,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s10,
          weight: AppTextWeight.regular,
          tone: AppTextTone.muted,
        ).copyWith(letterSpacing: 1.2),
      ),
    );
  }
}

/// 侧边栏一级导航的滚动区。当内容溢出、底部仍可下滑时，在底部叠一层
/// 透明→底色的渐隐遮罩，提示「下面还有内容」；滚到底自动消失。
/// 遮罩为纯装饰（[IgnorePointer]），不拦截对底部菜单项的点击。
/// 桌面侧栏不需要滚动条：用 [ScrollConfiguration] 关掉全局
/// [MaterialScrollBehavior] 自动叠加的滚动条，保留滚轮/拖拽滚动。
class _SidebarNavScrollArea extends StatefulWidget {
  const _SidebarNavScrollArea({
    required this.horizontalPadding,
    required this.fadeColor,
    required this.children,
  });

  final double horizontalPadding;
  final Color fadeColor;
  final List<Widget> children;

  @override
  State<_SidebarNavScrollArea> createState() => _SidebarNavScrollAreaState();
}

class _SidebarNavScrollAreaState extends State<_SidebarNavScrollArea> {
  final ScrollController _controller = ScrollController();
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_recompute);
    _scheduleRecompute();
  }

  @override
  void didUpdateWidget(covariant _SidebarNavScrollArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 折叠/展开或导航内容变化会改变溢出状态，下一帧重新评估。
    _scheduleRecompute();
  }

  @override
  void dispose() {
    _controller.removeListener(_recompute);
    _controller.dispose();
    super.dispose();
  }

  void _scheduleRecompute() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _recompute());
  }

  void _recompute() {
    if (!mounted || !_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    final canScrollDown =
        position.maxScrollExtent > 0 &&
        position.pixels < position.maxScrollExtent - 1.0;
    if (canScrollDown != _canScrollDown) {
      setState(() => _canScrollDown = canScrollDown);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        // 视口或内容尺寸变化（如窗口 resize）时同步重算。
        _scheduleRecompute();
        return false;
      },
      child: Stack(
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              controller: _controller,
              padding: EdgeInsets.symmetric(
                horizontal: widget.horizontalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: widget.children,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _canScrollDown ? 1 : 0,
                child: Container(
                  key: const Key('sidebar-nav-scroll-fade'),
                  height: _sidebarNavFadeHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.fadeColor.withValues(alpha: 0),
                        widget.fadeColor,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const double _sidebarNavFadeHeight = 32;

class AppSidebarGroup extends ConsumerWidget {
  const AppSidebarGroup({
    super.key,
    required this.group,
    required this.currentPath,
  });

  final AppNavGroup group;
  final String currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryItem = group.items.first;

    AppSidebarItem buildItem(int? badgeCount) {
      return AppSidebarItem(
        key: Key('nav-group-${group.id}'),
        icon: group.icon,
        label: group.label,
        selected: currentPath == primaryItem.path,
        badgeCount: badgeCount,
        onTap: () => context.goPrimaryRoute(primaryItem.path),
      );
    }

    // 仅「通知」组订阅全局未读数，其它组不监听、避免无谓重建。
    if (group.id != 'notifications') {
      return buildItem(null);
    }
    final unreadCount = ref.watch(
      notificationCenterProvider.select((value) => value.unreadCount),
    );
    return buildItem(unreadCount);
  }
}

class AppSidebarItem extends StatefulWidget {
  const AppSidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.selected,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  /// 尾部未读角标数；`null` 或 `<= 0` 不显示。
  final int? badgeCount;

  @override
  State<AppSidebarItem> createState() => _AppSidebarItemState();
}

class _AppSidebarItemState extends State<AppSidebarItem> {
  bool _hovered = false;

  bool get _hasBadge => (widget.badgeCount ?? 0) > 0;

  String get _badgeLabel {
    final count = widget.badgeCount ?? 0;
    return count > 99 ? '99+' : '$count';
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final sidebarTokens = context.appSidebarTokens;
    final useDesktopSidebarGlass = _useDesktopSidebarGlass;
    final isHovered = _hovered && !widget.selected;
    final backgroundColor = useDesktopSidebarGlass
        ? widget.selected
              ? appColors.desktopSidebarGlassActive
              : isHovered
              ? appColors.desktopSidebarGlassHover
              : Colors.transparent
        : widget.selected
        ? appColors.sidebarActiveBackground
        : isHovered
        ? appColors.sidebarHoverBackground
        : appColors.sidebarBackground;

    final foregroundColor = context.appTextPalette.primary;
    final labelStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s14,
      weight: widget.selected ? AppTextWeight.medium : AppTextWeight.regular,
      tone: widget.selected ? AppTextTone.primary : AppTextTone.secondary,
    );

    return Tooltip(
      message: widget.label,
      waitDuration: const Duration(milliseconds: 300),
      child: Padding(
        padding: EdgeInsets.only(bottom: context.appSpacing.xs),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: context.appRadius.smBorder,
            mouseCursor: SystemMouseCursors.click,
            onTap: widget.onTap,
            onHover: (hovered) {
              if (_hovered == hovered) {
                return;
              }
              setState(() => _hovered = hovered);
            },
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            focusColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: sidebarTokens.itemHeight,
              padding: EdgeInsets.symmetric(horizontal: context.appSpacing.md),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: context.appRadius.smBorder,
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: context.appComponentTokens.iconSizeSm,
                    color: foregroundColor,
                  ),
                  SizedBox(width: context.appSpacing.md),
                  Expanded(child: Text(widget.label, style: labelStyle)),
                  if (_hasBadge) ...[
                    SizedBox(width: context.appSpacing.sm),
                    AppBadge(
                      key: const Key('sidebar-item-badge'),
                      label: _badgeLabel,
                      tone: AppBadgeTone.error,
                      size: AppBadgeSize.compact,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool get _useDesktopSidebarGlass =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows);
