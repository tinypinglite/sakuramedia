import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

const List<double> kMoviePlayerPlaybackRates = <double>[
  2.0,
  1.75,
  1.5,
  1.25,
  1.0,
  0.75,
  0.5,
];

const Duration _moviePlayerSpeedMenuCloseDelay = Duration(milliseconds: 80);

class MoviePlayerSpeedButton extends StatefulWidget {
  const MoviePlayerSpeedButton({
    super.key,
    required this.currentRate,
    required this.hasExplicitSelection,
    required this.onRateSelected,
  });

  final double currentRate;
  final bool hasExplicitSelection;
  final Future<void> Function(double rate) onRateSelected;

  @override
  State<MoviePlayerSpeedButton> createState() => _MoviePlayerSpeedButtonState();
}

class _MoviePlayerSpeedButtonState extends State<MoviePlayerSpeedButton> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _buttonKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  Timer? _closeTimer;
  bool _isButtonHovered = false;
  bool _isMenuHovered = false;
  bool _isSelectingRate = false;
  double? _hoveredRate;
  late double _displayRate;
  late bool _displayHasExplicitSelection;
  double _buttonWidth = 0;
  Rect? _buttonRect;
  Rect? _menuRect;

  double get _menuHeight =>
      (kMoviePlayerPlaybackRates.length *
          context.appOverlayTokens.menuItemHeight) +
      (context.appOverlayTokens.menuVerticalPadding * 2);

  @override
  void initState() {
    super.initState();
    _displayRate = widget.currentRate;
    _displayHasExplicitSelection = widget.hasExplicitSelection;
  }

  @override
  void didUpdateWidget(covariant MoviePlayerSpeedButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _displayRate = widget.currentRate;
    _displayHasExplicitSelection = widget.hasExplicitSelection;
    if ((oldWidget.currentRate - widget.currentRate).abs() >= 0.001 ||
        oldWidget.hasExplicitSelection != widget.hasExplicitSelection) {
      _overlayEntry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _removeOverlay(notify: false);
    super.dispose();
  }

  void _handleButtonEnter(PointerEnterEvent event) {
    if (_isSelectingRate) {
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
    if (_isSelectingRate) {
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
    _closeTimer = Timer(_moviePlayerSpeedMenuCloseDelay, () {
      if (!_isButtonHovered && !_isMenuHovered) {
        _removeOverlay();
      }
    });
  }

  void _showOverlay() {
    if (_isSelectingRate) {
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
      return;
    }

    final buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    _buttonWidth = buttonBox.size.width;
    _buttonRect = buttonTopLeft & buttonBox.size;
    final overlayTokens = context.appOverlayTokens;
    _menuRect = Rect.fromLTWH(
      buttonTopLeft.dx + ((_buttonWidth - overlayTokens.menuWidthSm) / 2),
      buttonTopLeft.dy - (_menuHeight + overlayTokens.menuGap),
      overlayTokens.menuWidthSm,
      _menuHeight + overlayTokens.menuGap,
    );
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_overlayEntry!);
    if (mounted) {
      setState(() {});
    }
  }

  void _removeOverlay({bool notify = true}) {
    _closeTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _hoveredRate = null;
    _buttonRect = null;
    _menuRect = null;
    if (notify && mounted) {
      setState(() {});
    }
  }

  void _handleOverlayHover(PointerHoverEvent event) {
    if (_isSelectingRate) {
      return;
    }
    final buttonRect = _buttonRect;
    final menuRect = _menuRect;
    if (buttonRect == null || menuRect == null) {
      return;
    }
    final position = event.position;
    _isButtonHovered = buttonRect.contains(position);
    _isMenuHovered = menuRect.contains(position);
    if (_isButtonHovered || _isMenuHovered) {
      _closeTimer?.cancel();
      return;
    }
    _removeOverlay();
  }

  void _handleOverlayPointerDown(PointerDownEvent event) {
    if (_isSelectingRate) {
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

  Future<void> _handleRateSelected(double rate) async {
    if (_isSelectingRate) {
      return;
    }
    setState(() {
      _isSelectingRate = true;
      _displayRate = rate;
      _displayHasExplicitSelection = true;
    });
    try {
      await widget.onRateSelected(rate);
    } finally {
      if (mounted) {
        _removeOverlay(notify: false);
        setState(() {
          _isSelectingRate = false;
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
                      (_buttonWidth - overlayTokens.menuWidthSm) / 2,
                      -(_menuHeight + overlayTokens.menuGap),
                    ),
                    child: MouseRegion(
                      onEnter: _handleMenuEnter,
                      onExit: _handleMenuExit,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MoviePlayerSpeedMenu(
                            currentRate: _displayRate,
                            hoveredRate: _hoveredRate,
                            onHoveredRateChanged: (rate) {
                              if (_hoveredRate == rate) {
                                return;
                              }
                              _hoveredRate = rate;
                              _overlayEntry?.markNeedsBuild();
                            },
                            onRateSelected: _handleRateSelected,
                          ),
                          SizedBox(
                            width: overlayTokens.menuWidthSm,
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
    final label =
        _displayHasExplicitSelection ? _formatRateLabel(_displayRate) : '倍速';

    return MouseRegion(
      onEnter: _handleButtonEnter,
      onExit: _handleButtonExit,
      child: GestureDetector(
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
              label,
              key: const Key('movie-player-speed-button'),
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

class _MoviePlayerSpeedMenu extends StatelessWidget {
  const _MoviePlayerSpeedMenu({
    required this.currentRate,
    required this.hoveredRate,
    required this.onHoveredRateChanged,
    required this.onRateSelected,
  });

  final double currentRate;
  final double? hoveredRate;
  final ValueChanged<double?> onHoveredRateChanged;
  final ValueChanged<double> onRateSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final overlayTokens = context.appOverlayTokens;

    return Container(
      key: const Key('movie-player-speed-menu'),
      width: overlayTokens.menuWidthSm,
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
        children: kMoviePlayerPlaybackRates
            .map(
              (rate) => _MoviePlayerSpeedMenuItem(
                rate: rate,
                selected: _matchesRate(currentRate, rate),
                hovered:
                    hoveredRate != null && _matchesRate(hoveredRate!, rate),
                onHoverChanged: (hovered) {
                  onHoveredRateChanged(hovered ? rate : null);
                },
                onTap: () => onRateSelected(rate),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  bool _matchesRate(double left, double right) => (left - right).abs() < 0.001;
}

class _MoviePlayerSpeedMenuItem extends StatelessWidget {
  const _MoviePlayerSpeedMenuItem({
    required this.rate,
    required this.selected,
    required this.hovered,
    required this.onHoverChanged,
    required this.onTap,
  });

  final double rate;
  final bool selected;
  final bool hovered;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;
    final label = _formatRateLabel(rate);
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
          key: Key('movie-player-speed-menu-item-${_rateKey(rate)}'),
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
                      'movie-player-speed-menu-item-label-${_rateKey(rate)}',
                    ),
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      tone: selected ? AppTextTone.accent : AppTextTone.onMedia,
                    ),
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
                              'movie-player-speed-menu-item-check-${_rateKey(rate)}',
                            ),
                            size: overlayTokens.controlCheckIconSize,
                            color: selectedColor,
                          )
                          : SizedBox(
                            key: Key(
                              'movie-player-speed-menu-item-check-slot-${_rateKey(rate)}',
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

String _formatRateLabel(double rate) {
  final hundredths = (rate * 100).round();
  if (hundredths % 100 == 0 || hundredths % 50 == 0) {
    return '${rate.toStringAsFixed(1)}x';
  }
  return '${rate.toStringAsFixed(2)}x';
}

String _rateKey(double rate) => rate.toString().replaceAll('.', '_');
