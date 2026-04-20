import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/presentation/movie_player_subtitle_state.dart';
import 'package:sakuramedia/theme.dart';

const Duration _subtitleMenuCloseDelay = Duration(milliseconds: 80);
const String _noAvailableSubtitleLabel = '无可用字幕';

class MoviePlayerSubtitleButton extends StatefulWidget {
  const MoviePlayerSubtitleButton({
    super.key,
    required this.subtitleStateListenable,
    required this.isApplyingListenable,
    required this.onSubtitleSelected,
    required this.onReloadRequested,
  });

  final ValueListenable<MoviePlayerSubtitleState> subtitleStateListenable;
  final ValueListenable<bool> isApplyingListenable;
  final Future<void> Function(int? subtitleId) onSubtitleSelected;
  final Future<void> Function() onReloadRequested;

  @override
  State<MoviePlayerSubtitleButton> createState() =>
      _MoviePlayerSubtitleButtonState();
}

class _MoviePlayerSubtitleButtonState extends State<MoviePlayerSubtitleButton> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _buttonKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  Timer? _closeTimer;
  bool _isButtonHovered = false;
  bool _isMenuHovered = false;
  bool _isSelectingSubtitle = false;
  int? _hoveredSubtitleId;
  double _buttonWidth = 0;
  Rect? _buttonRect;
  Rect? _menuRect;
  Rect? _menuHoverRect;

  late MoviePlayerSubtitleState _subtitleState;
  late bool _isApplying;

  double get _menuHeight =>
      (_effectiveMenuItemCount * context.appOverlayTokens.menuItemHeight) +
      (context.appOverlayTokens.menuVerticalPadding * 2);
  int get _effectiveMenuItemCount =>
      _subtitleState.options.isEmpty ? 1 : _subtitleState.options.length;

  bool get _canInteract => !_isSelectingSubtitle && !_isApplying;

  @override
  void initState() {
    super.initState();
    _subtitleState = widget.subtitleStateListenable.value;
    _isApplying = widget.isApplyingListenable.value;
    widget.subtitleStateListenable.addListener(_handleSubtitleStateChanged);
    widget.isApplyingListenable.addListener(_handleApplyingStateChanged);
  }

  @override
  void didUpdateWidget(covariant MoviePlayerSubtitleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subtitleStateListenable != widget.subtitleStateListenable) {
      oldWidget.subtitleStateListenable.removeListener(
        _handleSubtitleStateChanged,
      );
      _subtitleState = widget.subtitleStateListenable.value;
      widget.subtitleStateListenable.addListener(_handleSubtitleStateChanged);
    }
    if (oldWidget.isApplyingListenable != widget.isApplyingListenable) {
      oldWidget.isApplyingListenable.removeListener(
        _handleApplyingStateChanged,
      );
      _isApplying = widget.isApplyingListenable.value;
      widget.isApplyingListenable.addListener(_handleApplyingStateChanged);
    }
    _overlayEntry?.markNeedsBuild();
  }

  @override
  void dispose() {
    widget.subtitleStateListenable.removeListener(_handleSubtitleStateChanged);
    widget.isApplyingListenable.removeListener(_handleApplyingStateChanged);
    _closeTimer?.cancel();
    _removeOverlay(notify: false);
    super.dispose();
  }

  void _handleSubtitleStateChanged() {
    _subtitleState = widget.subtitleStateListenable.value;
    _refreshMenuGeometry();
    _overlayEntry?.markNeedsBuild();
    if (mounted) {
      setState(() {});
    }
  }

  void _handleApplyingStateChanged() {
    _isApplying = widget.isApplyingListenable.value;
    if (_isApplying) {
      _removeOverlay();
    } else {
      _overlayEntry?.markNeedsBuild();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _handleButtonEnter(PointerEnterEvent event) {
    if (!_canInteract) {
      return;
    }
    _isButtonHovered = true;
    _closeTimer?.cancel();
    _showOverlay();
  }

  void _handleButtonExit(PointerExitEvent event) {
    _isButtonHovered = false;
    _scheduleCloseIfNeeded();
  }

  void _handleButtonTap() {
    if (!_canInteract) {
      return;
    }
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }
    _showOverlay();
  }

  void _handleMenuEnter(PointerEnterEvent event) {
    _isMenuHovered = true;
    _closeTimer?.cancel();
  }

  void _handleMenuExit(PointerExitEvent event) {
    _isMenuHovered = false;
    _scheduleCloseIfNeeded();
  }

  void _scheduleCloseIfNeeded() {
    _closeTimer?.cancel();
    if (_isButtonHovered || _isMenuHovered) {
      return;
    }
    _closeTimer = Timer(_subtitleMenuCloseDelay, () {
      if (!_isButtonHovered && !_isMenuHovered) {
        _removeOverlay();
      }
    });
  }

  void _showOverlay() {
    if (!_canInteract) {
      return;
    }
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }

    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final buttonBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null || buttonBox == null) {
      debugPrint(
        '[player-debug] subtitle_menu_aborted reason=missing_render_box',
      );
      return;
    }

    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    _buttonWidth = buttonBox.size.width;
    _buttonRect = buttonTopLeft & buttonBox.size;
    _refreshMenuGeometry();
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_overlayEntry!);
    if (mounted) {
      setState(() {});
    }
  }

  void _refreshMenuGeometry() {
    final buttonRect = _buttonRect;
    if (buttonRect == null) {
      return;
    }
    final overlayTokens = context.appOverlayTokens;
    _menuRect = Rect.fromLTWH(
      buttonRect.left + ((_buttonWidth - overlayTokens.menuWidthMd) / 2),
      buttonRect.top - (_menuHeight + overlayTokens.menuGap),
      overlayTokens.menuWidthMd,
      _menuHeight + overlayTokens.menuGap,
    );
    _menuHoverRect = Rect.fromLTRB(
      _menuRect!.left,
      _menuRect!.top - overlayTokens.menuItemHeight,
      _menuRect!.right,
      buttonRect.top > _menuRect!.bottom ? buttonRect.top : _menuRect!.bottom,
    );
  }

  void _removeOverlay({bool notify = true}) {
    _closeTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _hoveredSubtitleId = null;
    _buttonRect = null;
    _menuRect = null;
    _menuHoverRect = null;
    if (notify && mounted) {
      setState(() {});
    }
  }

  void _handleOverlayHover(PointerHoverEvent event) {
    if (!_canInteract) {
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
    _removeOverlay();
  }

  void _handleOverlayPointerDown(PointerDownEvent event) {
    if (!_canInteract) {
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
      _removeOverlay();
    }
  }

  Future<void> _handleSubtitleSelected(int subtitleId) async {
    if (!_canInteract) {
      return;
    }
    setState(() {
      _isSelectingSubtitle = true;
    });
    try {
      await widget.onSubtitleSelected(subtitleId);
    } finally {
      if (mounted) {
        _removeOverlay(notify: false);
        setState(() {
          _isSelectingSubtitle = false;
        });
      } else {
        _removeOverlay(notify: false);
      }
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
                    link: _layerLink,
                    showWhenUnlinked: false,
                    offset: Offset(
                      (_buttonWidth - overlayTokens.menuWidthMd) / 2,
                      -(_menuHeight + overlayTokens.menuGap),
                    ),
                    child: MouseRegion(
                      onEnter: _handleMenuEnter,
                      onExit: _handleMenuExit,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MoviePlayerSubtitleMenu(
                            options: _subtitleState.options,
                            selectedSubtitleId:
                                _subtitleState.selectedSubtitleId,
                            hoveredSubtitleId: _hoveredSubtitleId,
                            onHoveredSubtitleChanged: (subtitleId) {
                              if (_hoveredSubtitleId == subtitleId) {
                                return;
                              }
                              _hoveredSubtitleId = subtitleId;
                              _overlayEntry?.markNeedsBuild();
                            },
                            onSubtitleSelected: _handleSubtitleSelected,
                          ),
                          SizedBox(
                            width: overlayTokens.menuWidthMd,
                            height: overlayTokens.menuGap,
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;

    return MouseRegion(
      onEnter: _handleButtonEnter,
      onExit: _handleButtonExit,
      child: GestureDetector(
        key: const Key('movie-player-subtitle-button'),
        behavior: HitTestBehavior.opaque,
        onTap: _handleButtonTap,
        child: CompositedTransformTarget(
          link: _layerLink,
          child: Container(
            key: _buttonKey,
            constraints: BoxConstraints(
              minWidth: overlayTokens.controlMinWidth,
              minHeight: overlayTokens.controlMinHeight,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: overlayTokens.controlHorizontalPadding,
              vertical: overlayTokens.controlVerticalPadding,
            ),
            alignment: Alignment.center,
            child: Text(
              '字幕',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                tone: AppTextTone.onMedia,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoviePlayerSubtitleMenu extends StatelessWidget {
  const _MoviePlayerSubtitleMenu({
    required this.options,
    required this.selectedSubtitleId,
    required this.hoveredSubtitleId,
    required this.onHoveredSubtitleChanged,
    required this.onSubtitleSelected,
  });

  final List<MoviePlayerSubtitleOption> options;
  final int? selectedSubtitleId;
  final int? hoveredSubtitleId;
  final ValueChanged<int?> onHoveredSubtitleChanged;
  final ValueChanged<int> onSubtitleSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final overlayTokens = context.appOverlayTokens;
    final hasOptions = options.isNotEmpty;

    return Container(
      key: const Key('movie-player-subtitle-menu'),
      width: overlayTokens.menuWidthMd,
      padding: EdgeInsets.symmetric(
        vertical: overlayTokens.menuVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: colors.movieDetailHeroBackgroundStart.withValues(
          alpha: overlayTokens.darkSurfaceAlpha,
        ),
        borderRadius: overlayTokens.surfaceBorderRadius,
        border: Border.all(
          color: context.appTextPalette.onMedia.withValues(
            alpha: overlayTokens.surfaceBorderAlpha,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: overlayTokens.surfaceShadowAlpha,
            ),
            blurRadius: overlayTokens.surfaceShadowBlur,
            offset: Offset(0, overlayTokens.surfaceShadowOffsetY),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children:
            hasOptions
                ? options
                    .map(
                      (option) => _MoviePlayerSubtitleMenuItem(
                        subtitleId: option.subtitleId,
                        label: option.label,
                        selected: selectedSubtitleId == option.subtitleId,
                        hovered: hoveredSubtitleId == option.subtitleId,
                        onHoverChanged: (hovered) {
                          onHoveredSubtitleChanged(
                            hovered ? option.subtitleId : null,
                          );
                        },
                        onTap: () => onSubtitleSelected(option.subtitleId),
                      ),
                    )
                    .toList(growable: false)
                : const <Widget>[_MoviePlayerSubtitleEmptyItem()],
      ),
    );
  }
}

class _MoviePlayerSubtitleEmptyItem extends StatelessWidget {
  const _MoviePlayerSubtitleEmptyItem();

  @override
  Widget build(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;
    return SizedBox(
      key: const Key('movie-player-subtitle-menu-empty'),
      height: overlayTokens.menuItemHeight,
      child: Center(
        child: Text(
          _noAvailableSubtitleLabel,
          key: const Key('movie-player-subtitle-menu-empty-label'),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            tone: AppTextTone.muted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _MoviePlayerSubtitleMenuItem extends StatelessWidget {
  const _MoviePlayerSubtitleMenuItem({
    required this.subtitleId,
    required this.label,
    required this.selected,
    required this.hovered,
    required this.onHoverChanged,
    required this.onTap,
  });

  final int subtitleId;
  final String label;
  final bool selected;
  final bool hovered;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;
    final selectedColor = resolveAppTextToneColor(context, AppTextTone.accent);
    final backgroundColor =
        hovered
            ? context.appTextPalette.onMedia.withValues(
              alpha: overlayTokens.hoverAlpha,
            )
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          key: Key('movie-player-subtitle-menu-item-$subtitleId'),
          height: overlayTokens.menuItemHeight,
          decoration: BoxDecoration(color: backgroundColor),
          child: Row(
            children: [
              SizedBox(width: overlayTokens.controlSideGap),
              SizedBox(width: overlayTokens.controlSideGap),
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    key: Key(
                      'movie-player-subtitle-menu-item-label-$subtitleId',
                    ),
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      tone: selected ? AppTextTone.accent : AppTextTone.onMedia,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              SizedBox(
                width: overlayTokens.controlCheckSlotWidth,
                child: Center(
                  child:
                      selected
                          ? Icon(
                            Icons.check_rounded,
                            key: Key(
                              'movie-player-subtitle-menu-item-check-$subtitleId',
                            ),
                            size: overlayTokens.controlCheckIconSize,
                            color: selectedColor,
                          )
                          : SizedBox(
                            key: Key(
                              'movie-player-subtitle-menu-item-check-slot-$subtitleId',
                            ),
                            width: overlayTokens.controlCheckIconSize,
                            height: overlayTokens.controlCheckIconSize,
                          ),
                ),
              ),
              SizedBox(width: overlayTokens.controlTrailingGap),
            ],
          ),
        ),
      ),
    );
  }
}
