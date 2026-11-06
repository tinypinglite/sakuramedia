import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/overlay_entry_rebuild.dart';

const Duration _hoverMenuCloseDelay = Duration(milliseconds: 80);

/// 播放器文字按钮 + 悬浮菜单的共享交互层。
///
/// 负责定位、hover 进出、点击外部关闭和 OverlayEntry 生命周期；菜单内容和
/// 按钮文案仍由各按钮提供。
mixin MoviePlayerHoverMenuStateMixin<T extends StatefulWidget> on State<T> {
  final LayerLink hoverMenuLayerLink = LayerLink();
  final GlobalKey hoverMenuButtonKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  Timer? _closeTimer;
  bool _isButtonHovered = false;
  bool _isMenuHovered = false;
  double _buttonWidth = 0;
  Rect? _buttonRect;
  Rect? _menuRect;
  Rect? _menuHoverRect;

  double get hoverMenuWidth;
  double get hoverMenuHeight;
  bool get canOpenHoverMenu;
  Widget buildHoverMenu(BuildContext context);
  Widget buildHoverMenuButtonContent(BuildContext context);

  Key? get hoverMenuButtonTapKey => null;

  /// 菜单关闭时清理各自的 hover 项。
  void onHoverMenuClosed() {}

  /// 菜单实际可命中的区域；字幕菜单需要额外覆盖菜单与按钮之间的空隙。
  Rect resolveHoverMenuHitRect(Rect menuRect, Rect buttonRect) => menuRect;

  @override
  void dispose() {
    _closeTimer?.cancel();
    removeHoverMenu(notify: false);
    super.dispose();
  }

  void rebuildHoverMenuOverlay() {
    requestOverlayEntryRebuild(_overlayEntry);
  }

  void refreshHoverMenuGeometry() {
    final buttonRect = _buttonRect;
    if (buttonRect == null) {
      return;
    }
    final overlayTokens = context.appOverlayTokens;
    _menuRect = Rect.fromLTWH(
      buttonRect.left + ((_buttonWidth - hoverMenuWidth) / 2),
      buttonRect.top - (hoverMenuHeight + overlayTokens.menuGap),
      hoverMenuWidth,
      hoverMenuHeight + overlayTokens.menuGap,
    );
    _menuHoverRect = resolveHoverMenuHitRect(_menuRect!, buttonRect);
  }

  void showHoverMenu() {
    if (!canOpenHoverMenu) {
      return;
    }
    if (_overlayEntry != null) {
      rebuildHoverMenuOverlay();
      return;
    }

    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final buttonBox =
        hoverMenuButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null || buttonBox == null) {
      return;
    }

    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    _buttonWidth = buttonBox.size.width;
    _buttonRect = buttonTopLeft & buttonBox.size;
    refreshHoverMenuGeometry();
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_overlayEntry!);
    if (mounted) {
      setState(() {});
    }
  }

  void removeHoverMenu({bool notify = true}) {
    _closeTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
    onHoverMenuClosed();
    _buttonRect = null;
    _menuRect = null;
    _menuHoverRect = null;
    if (notify && mounted) {
      setState(() {});
    }
  }

  void handleHoverMenuButtonEnter(PointerEnterEvent event) {
    if (!canOpenHoverMenu) {
      return;
    }
    _isButtonHovered = true;
    _closeTimer?.cancel();
    showHoverMenu();
  }

  void handleHoverMenuButtonExit(PointerExitEvent event) {
    _isButtonHovered = false;
    _scheduleCloseIfNeeded();
  }

  void handleHoverMenuButtonTap() {
    if (!canOpenHoverMenu) {
      return;
    }
    if (_overlayEntry != null) {
      removeHoverMenu();
      return;
    }
    showHoverMenu();
  }

  void handleHoverMenuEnter(PointerEnterEvent event) {
    _isMenuHovered = true;
    _closeTimer?.cancel();
  }

  void handleHoverMenuExit(PointerExitEvent event) {
    _isMenuHovered = false;
    _scheduleCloseIfNeeded();
  }

  void _scheduleCloseIfNeeded() {
    _closeTimer?.cancel();
    if (_isButtonHovered || _isMenuHovered) {
      return;
    }
    _closeTimer = Timer(_hoverMenuCloseDelay, () {
      if (!_isButtonHovered && !_isMenuHovered) {
        removeHoverMenu();
      }
    });
  }

  void _handleOverlayHover(PointerHoverEvent event) {
    if (!canOpenHoverMenu) {
      return;
    }
    final buttonRect = _buttonRect;
    final menuRect = _menuRect;
    final menuHoverRect = _menuHoverRect;
    if (buttonRect == null || menuRect == null || menuHoverRect == null) {
      return;
    }
    final position = event.position;
    _isButtonHovered = buttonRect.contains(position);
    _isMenuHovered = menuHoverRect.contains(position);
    if (_isButtonHovered || _isMenuHovered) {
      _closeTimer?.cancel();
      return;
    }
    removeHoverMenu();
  }

  void _handleOverlayPointerDown(PointerDownEvent event) {
    if (!canOpenHoverMenu) {
      return;
    }
    final buttonRect = _buttonRect;
    final menuRect = _menuRect;
    if (buttonRect == null || menuRect == null) {
      return;
    }
    final position = event.position;
    final hitsButton = buttonRect.contains(position);
    final hitsMenu = menuRect.contains(position);
    if (!hitsButton && !hitsMenu) {
      removeHoverMenu();
    }
  }

  Widget _buildOverlay(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handleOverlayPointerDown,
            child: MouseRegion(
              opaque: false,
              onHover: _handleOverlayHover,
              child: Stack(
                children: [
                  CompositedTransformFollower(
                    link: hoverMenuLayerLink,
                    showWhenUnlinked: false,
                    offset: Offset(
                      (_buttonWidth - hoverMenuWidth) / 2,
                      -(hoverMenuHeight + overlayTokens.menuGap),
                    ),
                    child: MouseRegion(
                      onEnter: handleHoverMenuEnter,
                      onExit: handleHoverMenuExit,
                      // OverlayEntry 不在 route 的 Material 子树内, 缺 Material 时
                      // DefaultTextStyle 会落到 WidgetsApp 的红色兜底样式(黄双下划线)。
                      child: Material(
                        color: Colors.transparent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            buildHoverMenu(context),
                            SizedBox(
                              width: hoverMenuWidth,
                              height: overlayTokens.menuGap,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildHoverMenuButton(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: handleHoverMenuButtonEnter,
      onExit: handleHoverMenuButtonExit,
      child: GestureDetector(
        key: hoverMenuButtonTapKey,
        behavior: HitTestBehavior.opaque,
        onTap: handleHoverMenuButtonTap,
        child: CompositedTransformTarget(
          link: hoverMenuLayerLink,
          child: Container(
            key: hoverMenuButtonKey,
            constraints: BoxConstraints(
              minWidth: overlayTokens.controlMinWidth,
              minHeight: overlayTokens.controlMinHeight,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: overlayTokens.controlHorizontalPadding,
              vertical: overlayTokens.controlVerticalPadding,
            ),
            alignment: Alignment.center,
            child: buildHoverMenuButtonContent(context),
          ),
        ),
      ),
    );
  }
}
