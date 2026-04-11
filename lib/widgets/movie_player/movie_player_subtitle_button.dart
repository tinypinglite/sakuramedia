import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/presentation/movie_player_subtitle_state.dart';
import 'package:sakuramedia/theme.dart';

const double _subtitleMenuWidth = 188;
const double _subtitleMenuItemHeight = 40;
const double _subtitleMenuVerticalPadding = 6;
const double _subtitleMenuGap = 6;
const double _subtitleMenuHoverTolerance = _subtitleMenuItemHeight;
const Duration _subtitleMenuCloseDelay = Duration(milliseconds: 80);

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
      (_subtitleState.options.length * _subtitleMenuItemHeight) +
      (_subtitleMenuVerticalPadding * 2);

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
    _menuRect = Rect.fromLTWH(
      buttonRect.left + ((_buttonWidth - _subtitleMenuWidth) / 2),
      buttonRect.top - (_menuHeight + _subtitleMenuGap),
      _subtitleMenuWidth,
      _menuHeight + _subtitleMenuGap,
    );
    _menuHoverRect = Rect.fromLTRB(
      _menuRect!.left,
      _menuRect!.top - _subtitleMenuHoverTolerance,
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
                      (_buttonWidth - _subtitleMenuWidth) / 2,
                      -(_menuHeight + _subtitleMenuGap),
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
                          const SizedBox(
                            width: _subtitleMenuWidth,
                            height: _subtitleMenuGap,
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
    final theme = Theme.of(context);

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
            constraints: const BoxConstraints(minWidth: 48, minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            alignment: Alignment.center,
            child: Text(
              '字幕',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.94),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.0,
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

    return Container(
      key: const Key('movie-player-subtitle-menu'),
      width: _subtitleMenuWidth,
      padding: const EdgeInsets.symmetric(
        vertical: _subtitleMenuVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: colors.movieDetailHeroBackgroundStart.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: options
            .map(
              (option) => _MoviePlayerSubtitleMenuItem(
                subtitleId: option.subtitleId,
                label: option.label,
                selected: selectedSubtitleId == option.subtitleId,
                hovered: hoveredSubtitleId == option.subtitleId,
                onHoverChanged: (hovered) {
                  onHoveredSubtitleChanged(hovered ? option.subtitleId : null);
                },
                onTap: () => onSubtitleSelected(option.subtitleId),
              ),
            )
            .toList(growable: false),
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
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    final textColor =
        selected ? selectedColor : Colors.white.withValues(alpha: 0.92);
    final backgroundColor =
        hovered ? Colors.white.withValues(alpha: 0.08) : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          key: Key('movie-player-subtitle-menu-item-$subtitleId'),
          height: _subtitleMenuItemHeight,
          decoration: BoxDecoration(color: backgroundColor),
          child: Row(
            children: [
              const SizedBox(width: 18),
              const SizedBox(width: 18),
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    key: Key(
                      'movie-player-subtitle-menu-item-label-$subtitleId',
                    ),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      height: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Center(
                  child:
                      selected
                          ? Icon(
                            Icons.check_rounded,
                            key: Key(
                              'movie-player-subtitle-menu-item-check-$subtitleId',
                            ),
                            size: 18,
                            color: selectedColor,
                          )
                          : SizedBox(
                            key: Key(
                              'movie-player-subtitle-menu-item-check-slot-$subtitleId',
                            ),
                            width: 18,
                            height: 18,
                          ),
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}
