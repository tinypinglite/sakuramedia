import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_state.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_window_drag_area.dart';
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
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.appSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: navGroups
                        .map(
                          (group) => Padding(
                            padding: EdgeInsets.only(
                              bottom: context.appSpacing.xs,
                            ),
                            child: AppSidebarGroup(
                              group: group,
                              currentPath: currentPath,
                              isCompact: isCompact,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
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
                    AppSidebarItem(
                      key: const Key('sidebar-logout-button'),
                      icon: Icons.logout_rounded,
                      label: '退出登录',
                      selected: false,
                      collapsed: isCompact,
                      onTap: () {
                        context.read<SessionStore>().clearSession();
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

    return AppSidebarItem(
      key: Key('nav-group-${group.id}'),
      icon: group.icon,
      label: group.label,
      selected: currentPath == primaryItem.path,
      collapsed: isCompact,
      onTap: () => context.goPrimaryRoute(primaryItem.path),
    );
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
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool collapsed;

  @override
  State<AppSidebarItem> createState() => _AppSidebarItemState();
}

class _AppSidebarItemState extends State<AppSidebarItem> {
  bool _hovered = false;

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
                  Icon(
                    widget.icon,
                    size: context.appComponentTokens.iconSizeSm,
                    color: foregroundColor,
                  ),
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
