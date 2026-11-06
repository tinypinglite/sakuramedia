import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_state.dart';
import 'package:sakuramedia/features/status/presentation/providers/server_capabilities_provider.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/domain/search/catalog_search_field.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_sidebar_toggle_button.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_top_bar_glass_refresh_button.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_top_bar_glass_search_field.dart';
import 'package:sakuramedia/widgets/shell/window/app_window_drag_area.dart';
import 'package:sakuramedia/widgets/shell/window/app_windows_caption.dart';

/// 桌面壳顶栏。
///
/// 刷新按钮是**受控组件**：[onRefresh] 只是「按下的动作」（fire-and-forget），
/// [isRefreshing] 由外部（[AppDesktopShell]）持有，用来切换按钮 / spinner。
/// 这样点击按钮和 Cmd/Ctrl+R 快捷键可以共用同一份 in-flight 闸门与错误 toast。
///
/// 侧边栏收起/展开按钮由壳层固定在窗口左上角（macOS 红绿灯右侧），
/// 不在这里渲染；收起态顶栏前导留白让出按钮占位，保证标题/返回按钮
/// 排在按钮右侧。
///
/// 搜索框固定显示在刷新按钮左侧，不再提供折叠按钮。只有概览的透明顶栏
/// 使用玻璃搜索框，其它仍为实色背景的页面继续使用标准搜索框。
class AppTopBar extends ConsumerWidget {
  const AppTopBar({
    super.key,
    required this.currentPath,
    required this.config,
    this.shellNavigatorKey,
    this.onRefresh,
    this.isRefreshing = false,
    this.overlay = false,
    this.translucent = false,
    this.contentLeadingInset = AppPageInsets.desktop,
    this.hideActions = false,
  });

  final String currentPath;
  final DesktopTopBarConfig config;
  final GlobalKey<NavigatorState>? shellNavigatorKey;
  final VoidCallback? onRefresh;
  final bool isRefreshing;

  /// 悬浮在沉浸内容之上：透明底 + 顶部压暗保证可读，无分隔线。
  final bool overlay;

  /// 桌面玻璃壳层：标准顶栏不再铺实色，直接露出环境背景。
  final bool translucent;

  /// 标准顶栏内容的左侧起始内边距；玻璃壳层下与页面内容共用紧凑 gutter。
  final double contentLeadingInset;

  /// 隐藏搜索/刷新动作（详情页用不到，快捷键刷新不受影响）。
  final bool hideActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSidebarCollapsed = ref.watch(appShellSidebarCollapsedProvider);
    // 收起态前导留白让出壳层固定的收起/展开按钮占位；与侧栏宽度
    // 用同款 180ms 线性动画，标题随之平滑滑动而不是跳变。
    final collapsedLeading =
        sidebarToggleButtonLeft(context) +
        sidebarToggleButtonSize +
        context.appSpacing.sm;

    return Container(
      key: const Key('desktop-shell-topbar'),
      decoration: overlay
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.appColors.mediaOverlayStrong.withValues(alpha: 0.55),
                  context.appColors.mediaOverlayStrong.withValues(alpha: 0),
                ],
              ),
            )
          : BoxDecoration(
              color: translucent
                  ? Colors.transparent
                  : context.appColors.surfaceElevated,
            ),
      child: Column(
        children: [
          SizedBox(
            key: const Key('topbar-header'),
            height: context.appComponentTokens.desktopTitleBarHeight,
            child: overlay
                ? _buildOverlayHeader(
                    context,
                    isSidebarCollapsed: isSidebarCollapsed,
                    collapsedLeading: collapsedLeading,
                  )
                : _buildStandardHeader(
                    context,
                    isSidebarCollapsed: isSidebarCollapsed,
                    collapsedLeading: collapsedLeading,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardHeader(
    BuildContext context, {
    required bool isSidebarCollapsed,
    required double collapsedLeading,
  }) {
    final spacing = context.appSpacing;
    final leftInset = contentLeadingInset;
    const rightInset = AppPageInsets.desktop;
    final backButtonSlotWidth = config.isBackEnabled ? 40.0 : 0.0;
    final titleLeadingGap = config.isBackEnabled ? spacing.sm : 0.0;
    final l10n = appL10n(context);

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: isSidebarCollapsed ? collapsedLeading : leftInset,
        ),
        if (config.isBackEnabled)
          SizedBox(
            width: backButtonSlotWidth,
            child: AppIconButton(
              key: const Key('topbar-back-button'),
              tooltip: l10n.shellBack,
              onPressed: () => _handleBack(context),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: context.appComponentTokens.iconSizeXs,
              ),
            ),
          ),
        if (titleLeadingGap > 0) SizedBox(width: titleLeadingGap),
        Expanded(
          child: AppWindowDragArea(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                config.title,
                key: const Key('app-topbar-title'),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
            ),
          ),
        ),
        if (!hideActions)
          _TopBarActions(
            currentPath: currentPath,
            glass: translucent,
            onRefresh: onRefresh,
            isRefreshing: isRefreshing,
          ),
        SizedBox(width: rightInset),
        if (usesAppWindowsCaption) AppWindowsCaption(),
      ],
    );
  }

  /// 沉浸页顶栏：只留一颗普通返回键（与其它顶栏同一套按钮），页面标题由
  /// 内容区自己承载。搜索/刷新在沉浸页通常隐藏；若调用方仍开启，则按普通
  /// 图标放在右侧。
  Widget _buildOverlayHeader(
    BuildContext context, {
    required bool isSidebarCollapsed,
    required double collapsedLeading,
  }) {
    const leftInset = AppPageInsets.desktop;
    const rightInset = AppPageInsets.desktop;
    final l10n = appL10n(context);

    return Row(
      children: [
        SizedBox(width: isSidebarCollapsed ? collapsedLeading : leftInset),
        if (config.isBackEnabled)
          SizedBox(
            width: 40.0,
            child: AppIconButton(
              key: const Key('topbar-back-button'),
              tooltip: l10n.shellBack,
              semanticLabel: l10n.shellBack,
              onPressed: () => _handleBack(context),
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: context.appComponentTokens.iconSizeXs,
                color: context.appTextPalette.onMedia,
              ),
            ),
          ),
        Expanded(child: AppWindowDragArea(child: const SizedBox.expand())),
        if (!hideActions)
          _TopBarActions(
            currentPath: currentPath,
            overlay: true,
            onRefresh: onRefresh,
            isRefreshing: isRefreshing,
          ),
        SizedBox(width: rightInset),
        if (usesAppWindowsCaption) AppWindowsCaption(overlay: true),
      ],
    );
  }

  Future<void> _handleBack(BuildContext context) async {
    final shellNavigator = shellNavigatorKey?.currentState;
    if (shellNavigator != null && shellNavigator.canPop()) {
      shellNavigator.pop();
      return;
    }

    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }

    final fallbackPath = config.fallbackPath;
    if (fallbackPath != null && fallbackPath != currentPath) {
      router.go(fallbackPath);
    }
  }
}

/// 顶栏搜索框与右侧刷新动作。
///
/// 搜索框固定显示；提交后跳转搜索页。输入框聚焦时按 ESC 清空并失焦，
/// 不隐藏输入框。以图搜图 / 文字搜图入口挂在输入框后缀。
class _TopBarActions extends ConsumerStatefulWidget {
  const _TopBarActions({
    required this.currentPath,
    this.overlay = false,
    this.glass = false,
    this.onRefresh,
    this.isRefreshing = false,
  });

  final String currentPath;
  final bool overlay;
  final bool glass;
  final VoidCallback? onRefresh;
  final bool isRefreshing;

  @override
  ConsumerState<_TopBarActions> createState() => _TopBarActionsState();
}

class _TopBarActionsState extends ConsumerState<_TopBarActions> {
  static const double _fieldWidth = 300;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'topbar-search');

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearAndUnfocus() {
    _controller.clear();
    _focusNode.unfocus();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return;
    }
    context.pushDesktopSearch(query: query, fallbackPath: widget.currentPath);
  }

  void _openTextImageSearch() {
    context.pushDesktopImageSearch(
      fallbackPath: widget.currentPath,
      initialInputKind: ImageSearchInputKind.text,
    );
  }

  Future<void> _pickAndOpenImageSearch() async {
    final l10n = appL10n(context);
    try {
      final pickedFile = await pickImageSearchFile(l10n: l10n);
      if (pickedFile == null || !mounted) {
        return;
      }
      context.pushDesktopImageSearch(
        fallbackPath: widget.currentPath,
        initialFileName: pickedFile.fileName,
        initialFileBytes: pickedFile.bytes,
        initialMimeType: pickedFile.mimeType,
      );
    } on ImageSearchFilePickerException catch (error) {
      if (mounted) {
        showToast(error.message, tone: AppToastTone.error);
      }
    } catch (_) {
      if (mounted) {
        showToast(l10n.shellImagePickFailed, tone: AppToastTone.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final imageSearchEnabled = ref.watch(imageSearchEnabledProvider);
    final searchField = widget.glass
        ? AppTopBarGlassSearchField(
            key: const Key('topbar-search-field'),
            fieldKey: const Key('topbar-search-input'),
            imageSearchButtonKey: const Key('topbar-search-image'),
            textImageSearchButtonKey: const Key('topbar-search-text-image'),
            controller: _controller,
            focusNode: _focusNode,
            hintText: l10n.shellSearchHintExample,
            onSubmitted: (_) => _submit(),
            showImageSearchButton: imageSearchEnabled,
            showTextImageSearchButton: imageSearchEnabled,
            onImageSearchTap: _pickAndOpenImageSearch,
            onTextImageSearchTap: _openTextImageSearch,
          )
        : CatalogSearchField(
            key: const Key('topbar-search-field'),
            fieldKey: const Key('topbar-search-input'),
            imageSearchButtonKey: const Key('topbar-search-image'),
            textImageSearchButtonKey: const Key('topbar-search-text-image'),
            controller: _controller,
            focusNode: _focusNode,
            hintText: l10n.shellSearchHintExample,
            // 收紧到 34 高：tightSuffix 解除后缀 48px 热区下限后，
            // 高度 = max(后缀按钮 28, 字高 14 + 2×10)。
            tightSuffix: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: context.appFormTokens.fieldHorizontalPadding,
              vertical: _compactSearchFieldVerticalPadding,
            ),
            // 34 高的字段上 8px 圆角偏圆，收紧到 4 更方。
            borderRadius: context.appRadius.xsBorder,
            showSearchButton: false,
            showImageSearchButton: imageSearchEnabled,
            showTextImageSearchButton: imageSearchEnabled,
            onSubmitted: (_) => _submit(),
            onImageSearchTap: _pickAndOpenImageSearch,
            onTextImageSearchTap: _openTextImageSearch,
          );
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final refresh = widget.onRefresh;
    final actions = refresh == null
        ? null
        : widget.glass && !highContrast
        ? AppTopBarGlassRefreshButton(
            onPressed: refresh,
            isRefreshing: widget.isRefreshing,
          )
        : _TopBarRefreshButton(
            onPressed: refresh,
            isRefreshing: widget.isRefreshing,
            overlay: widget.overlay,
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: _fieldWidth,
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.escape):
                  _clearAndUnfocus,
            },
            child: searchField,
          ),
        ),
        if (actions != null) ...[
          SizedBox(width: context.appSpacing.xs),
          actions,
        ],
      ],
    );
  }
}

/// 非玻璃顶栏刷新按钮的占位宽度，与 AppIconButton(compact) 同宽。
const double _topBarActionSlotWidth = appCompactIconButtonSize;

/// 顶栏搜索框收紧后的垂直内边距：字段高 = max(28, 字高 14 + 2×10) = 34。
///
/// 没有等于 10 的间距 token（xs=4 / md=12），收到这里的命名常量，
/// 避免在 `EdgeInsets` 里出现裸数字（theme_source_guard 禁令）。
const double _compactSearchFieldVerticalPadding = 10;

class _TopBarRefreshButton extends StatelessWidget {
  const _TopBarRefreshButton({
    required this.onPressed,
    required this.isRefreshing,
    this.overlay = false,
  });

  final VoidCallback onPressed;
  final bool isRefreshing;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final tokens = context.appComponentTokens;
    final iconSize = tokens.iconSizeSm;

    if (isRefreshing) {
      return SizedBox(
        key: const Key('topbar-refresh-button-loading'),
        width: _topBarActionSlotWidth,
        child: Center(
          child: SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator.adaptive(
              backgroundColor: switch (Theme.of(context).platform) {
                TargetPlatform.iOS || TargetPlatform.macOS =>
                  overlay
                      ? context.appTextPalette.onMedia
                      : context.appTextPalette.muted,
                _ => null,
              },
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color?>(
                overlay
                    ? context.appTextPalette.onMedia
                    : context.appTextPalette.muted,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: _topBarActionSlotWidth,
      child: AppIconButton(
        key: const Key('topbar-refresh-button'),
        tooltip: l10n.commonRefresh,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.refresh_rounded,
          size: iconSize,
          color: overlay ? context.appTextPalette.onMedia : null,
        ),
      ),
    );
  }
}
