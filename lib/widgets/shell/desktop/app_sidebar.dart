import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_state.dart';
import 'package:sakuramedia/app/app_version_info_controller.dart';
import 'package:sakuramedia/features/activity/presentation/notification_center_controller.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/shell/window/app_window_drag_area.dart';
import 'package:sakuramedia/widgets/search/catalog_search_field.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.currentPath,
    required this.navGroups,
  });

  final String currentPath;
  final List<AppNavGroup> navGroups;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppShellController>(
      builder: (context, controller, child) {
        final sidebarTokens = context.appSidebarTokens;
        final appColors = context.appColors;
        final useMacSidebarGlass = _useMacSidebarGlass;
        final width =
            controller.isSidebarCollapsed
                ? sidebarTokens.collapsedWidth
                : sidebarTokens.expandedWidth;
        final isCompact = controller.isSidebarCollapsed;

        return AnimatedContainer(
          key: const Key('desktop-shell-sidebar'),
          duration: const Duration(milliseconds: 180),
          width: width,
          decoration: BoxDecoration(
            color:
                useMacSidebarGlass
                    ? appColors.desktopSidebarGlassTint
                    : appColors.sidebarBackground,
            border: Border(
              right: BorderSide(
                color:
                    useMacSidebarGlass
                        ? appColors.borderSubtle.withValues(alpha: 0.68)
                        : appColors.borderSubtle,
              ),
            ),
            boxShadow: useMacSidebarGlass ? const [] : context.appShadows.panel,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: const Key('sidebar-header'),
                height: context.appComponentTokens.desktopTitleBarHeight,
                child: Builder(
                  builder: (context) {
                    final toggleButton = AppIconButton(
                      key: const Key('sidebar-toggle-button'),
                      iconColor: context.appTextPalette.primary,
                      onPressed: controller.toggleSidebar,
                      icon: Icon(isCompact ? Icons.menu_open : Icons.menu_open),
                    );
                    if (useMacSidebarGlass) {
                      return Stack(
                        children: [
                          const Positioned.fill(
                            child: AppWindowDragArea(
                              child: ColoredBox(color: Colors.transparent),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: context.appSpacing.xs,
                              ),
                              child: toggleButton,
                            ),
                          ),
                        ],
                      );
                    }
                    return Center(child: toggleButton);
                  },
                ),
              ),
              Divider(
                key: const Key('sidebar-header-divider'),
                height: 1,
                color: _sidebarDividerColor(appColors, useMacSidebarGlass),
              ),
              Padding(
                padding: EdgeInsets.all(context.appSpacing.sm),
                child: _SidebarSearchSection(
                  currentPath: currentPath,
                  isCompact: isCompact,
                ),
              ),
              Expanded(
                child: _SidebarNavScrollArea(
                  horizontalPadding: context.appSpacing.sm,
                  fadeColor:
                      useMacSidebarGlass
                          ? appColors.desktopSidebarGlassTint
                          : appColors.sidebarBackground,
                  children: _buildNavChildren(context, isCompact),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(context.appSpacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Divider(
                      height: 1,
                      color: _sidebarDividerColor(
                        appColors,
                        useMacSidebarGlass,
                      ),
                    ),
                    SizedBox(height: context.appSpacing.sm),
                    _SidebarVersionInfo(isCompact: isCompact),
                    SizedBox(height: context.appSpacing.sm),
                    AppSidebarItem(
                      key: const Key('sidebar-logout-button'),
                      icon: Icons.logout_rounded,
                      label: '退出登录',
                      selected: false,
                      collapsed: isCompact,
                      onTap: () {
                        context.logOut();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildNavChildren(BuildContext context, bool isCompact) {
    final children = <Widget>[];
    String? previousSection;
    for (final group in navGroups) {
      final section = group.sectionLabel;
      if (section != null && section != previousSection) {
        children.add(
          _SidebarSectionHeader(label: section, isCompact: isCompact),
        );
      }
      previousSection = section;
      children.add(
        Padding(
          padding: EdgeInsets.only(bottom: context.appSpacing.xs),
          child: AppSidebarGroup(
            group: group,
            currentPath: currentPath,
            isCompact: isCompact,
          ),
        ),
      );
    }
    return children;
  }
}

class _SidebarSectionHeader extends StatelessWidget {
  const _SidebarSectionHeader({required this.label, required this.isCompact});

  final String label;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final key = Key('sidebar-section-$label');
    if (isCompact) {
      return Padding(
        key: key,
        padding: EdgeInsets.symmetric(vertical: context.appSpacing.xs),
        child: Divider(
          height: 1,
          color: _sidebarDividerColor(context.appColors, _useMacSidebarGlass),
        ),
      );
    }
    return Padding(
      key: key,
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
          weight: AppTextWeight.medium,
          tone: AppTextTone.muted,
        ).copyWith(letterSpacing: 1.2),
      ),
    );
  }
}

/// 侧边栏一级导航的滚动区。当内容溢出、底部仍可下滑时，在底部叠一层
/// 透明→底色的渐隐遮罩，提示「下面还有内容」；滚到底自动消失。
/// 遮罩为纯装饰（[IgnorePointer]），不拦截对底部菜单项的点击。
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
          SingleChildScrollView(
            controller: _controller,
            padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
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

class _SidebarVersionInfo extends StatefulWidget {
  const _SidebarVersionInfo({required this.isCompact});

  final bool isCompact;

  @override
  State<_SidebarVersionInfo> createState() => _SidebarVersionInfoState();
}

class _SidebarVersionInfoState extends State<_SidebarVersionInfo> {
  AppVersionInfoController? _loadedController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = _readVersionInfoController(context);
    if (controller == null || identical(controller, _loadedController)) {
      return;
    }
    _loadedController = controller;
    unawaited(controller.load());
  }

  @override
  Widget build(BuildContext context) {
    final controller = _watchVersionInfoController(context);
    final frontendVersion = controller?.frontendVersionLabel ?? '--';
    final backendVersion = controller?.backendVersionLabel ?? '--';

    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldUseCompact =
            widget.isCompact || constraints.maxWidth < sidebarVersionMinWidth;
        if (shouldUseCompact) {
          return Tooltip(
            message:
                controller?.tooltipLabel ??
                '客户端 $frontendVersion · 服务端 $backendVersion',
            waitDuration: const Duration(milliseconds: 300),
            child: Center(
              child: Container(
                key: const Key('sidebar-version-info-collapsed'),
                width: context.appSidebarTokens.itemHeight,
                height: context.appSidebarTokens.itemHeight,
                decoration: BoxDecoration(
                  color: context.appColors.surfaceMuted,
                  borderRadius: context.appRadius.smBorder,
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: context.appComponentTokens.iconSizeSm,
                  color: context.appTextPalette.muted,
                ),
              ),
            ),
          );
        }

        return Padding(
          key: const Key('sidebar-version-info'),
          padding: EdgeInsets.all(context.appSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '系统版本',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.medium,
                  tone: AppTextTone.tertiary,
                ),
              ),
              SizedBox(height: context.appSpacing.xs),
              _SidebarVersionRow(label: '客户端', value: frontendVersion),
              SizedBox(height: context.appSpacing.xs),
              _SidebarVersionRow(label: '服务端', value: backendVersion),
            ],
          ),
        );
      },
    );
  }
}

const double sidebarVersionMinWidth = 144;

class _SidebarVersionRow extends StatelessWidget {
  const _SidebarVersionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(width: context.appSpacing.sm),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.medium,
              tone: AppTextTone.tertiary,
            ),
          ),
        ),
      ],
    );
  }
}

AppVersionInfoController? _readVersionInfoController(BuildContext context) {
  try {
    return context.read<AppVersionInfoController>();
  } on ProviderNotFoundException {
    return null;
  }
}

AppVersionInfoController? _watchVersionInfoController(BuildContext context) {
  try {
    return context.watch<AppVersionInfoController>();
  } on ProviderNotFoundException {
    return null;
  }
}

class AppSidebarGroup extends StatelessWidget {
  const AppSidebarGroup({
    super.key,
    required this.group,
    required this.currentPath,
    required this.isCompact,
  });

  final AppNavGroup group;
  final String currentPath;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final primaryItem = group.items.first;
    // 仅「通知」组订阅全局未读数，其它组不 watch、避免无谓重建。
    final badgeCount =
        group.id == 'notifications'
            ? _watchNotificationUnreadCount(context)
            : null;

    return AppSidebarItem(
      key: Key('nav-group-${group.id}'),
      icon: group.icon,
      label: group.label,
      selected: currentPath == primaryItem.path,
      collapsed: isCompact,
      badgeCount: badgeCount,
      onTap: () => context.goPrimaryRoute(primaryItem.path),
    );
  }
}

/// 防御式读取全局未读数：缺 Provider（如部分 widget 测试）时返回 null 不显示角标，
/// 而非抛 [ProviderNotFoundException]。
int? _watchNotificationUnreadCount(BuildContext context) {
  try {
    return context.watch<NotificationCenterController>().unreadCount;
  } on ProviderNotFoundException {
    return null;
  }
}

class _SidebarSearchSection extends StatefulWidget {
  const _SidebarSearchSection({
    required this.currentPath,
    required this.isCompact,
  });

  final String currentPath;
  final bool isCompact;

  @override
  State<_SidebarSearchSection> createState() => _SidebarSearchSectionState();
}

class _SidebarSearchSectionState extends State<_SidebarSearchSection> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldUseCompact = widget.isCompact || constraints.maxWidth < 160;
        if (shouldUseCompact) {
          return Material(
            color: context.appColors.surfaceMuted,
            borderRadius: context.appRadius.smBorder,
            child: InkWell(
              key: const Key('sidebar-search-button'),
              onTap:
                  () => context.pushDesktopSearch(
                    query: '',
                    fallbackPath: widget.currentPath,
                  ),
              borderRadius: context.appRadius.smBorder,
              child: SizedBox(
                height: context.appSidebarTokens.itemHeight,
                child: Center(
                  child: Icon(
                    Icons.search_rounded,
                    size: context.appComponentTokens.iconSizeSm,
                  ),
                ),
              ),
            ),
          );
        }

        return CatalogSearchField(
          key: const Key('sidebar-search-field'),
          fieldKey: const Key('sidebar-search-input'),
          searchButtonKey: const Key('sidebar-search-submit'),
          imageSearchButtonKey: const Key('sidebar-search-image'),
          controller: _controller,
          hintText: '找影片',
          compact: true,
          showImageSearchButton: true,
          onSubmitted: (_) => _submit(context),
          onImageSearchTap: () => _pickAndOpenImageSearch(context),
          onSearchTap: () => _submit(context),
        );
      },
    );
  }

  void _submit(BuildContext context) {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return;
    }
    context.pushDesktopSearch(query: query, fallbackPath: widget.currentPath);
    _controller.clear();
  }

  Future<void> _pickAndOpenImageSearch(BuildContext context) async {
    try {
      final pickedFile = await pickImageSearchFile();
      if (pickedFile == null || !context.mounted) {
        return;
      }
      context.pushDesktopImageSearch(
        fallbackPath: widget.currentPath,
        initialFileName: pickedFile.fileName,
        initialFileBytes: pickedFile.bytes,
        initialMimeType: pickedFile.mimeType,
      );
    } on ImageSearchFilePickerException catch (error) {
      if (context.mounted) {
        showToast(error.message);
      }
    } catch (_) {
      if (context.mounted) {
        showToast('选择图片失败');
      }
    }
  }
}

class AppSidebarItem extends StatefulWidget {
  const AppSidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.selected,
    required this.collapsed,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool collapsed;

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

  /// 折叠态时在图标右上角叠一个未读小红点（不显示数字，避免拥挤）。
  Widget _buildIcon(BuildContext context, Color color) {
    final icon = Icon(
      widget.icon,
      size: context.appComponentTokens.iconSizeSm,
      color: color,
    );
    if (!widget.collapsed || !_hasBadge) {
      return icon;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -3,
          top: -2,
          child: Container(
            key: const Key('sidebar-item-badge-dot'),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: context.appTextPalette.error,
              shape: BoxShape.circle,
              border: Border.all(
                color: context.appColors.sidebarBackground,
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final sidebarTokens = context.appSidebarTokens;
    final useMacSidebarGlass = _useMacSidebarGlass;
    final isHovered = _hovered && !widget.selected;
    final backgroundColor =
        useMacSidebarGlass
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
              padding: EdgeInsets.symmetric(
                horizontal:
                    widget.collapsed
                        ? context.appSpacing.sm
                        : context.appSpacing.md,
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: context.appRadius.smBorder,
              ),
              child: Row(
                mainAxisAlignment:
                    widget.collapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                children: [
                  _buildIcon(context, foregroundColor),
                  if (!widget.collapsed) ...[
                    SizedBox(width: context.appSpacing.md),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          weight: AppTextWeight.medium,
                          tone: AppTextTone.tertiary,
                        ),
                      ),
                    ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool get _useMacSidebarGlass =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

Color _sidebarDividerColor(AppColors appColors, bool useMacSidebarGlass) =>
    useMacSidebarGlass
        ? appColors.borderSubtle.withValues(alpha: 0.68)
        : appColors.borderSubtle;
