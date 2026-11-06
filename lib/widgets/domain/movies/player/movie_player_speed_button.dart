import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_surface.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_hover_menu.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_menu_widgets.dart';

const List<double> kMoviePlayerPlaybackRates = <double>[
  2.0,
  1.75,
  1.5,
  1.25,
  1.0,
  0.75,
  0.5,
];

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

class _MoviePlayerSpeedButtonState extends State<MoviePlayerSpeedButton>
    with MoviePlayerHoverMenuStateMixin<MoviePlayerSpeedButton> {
  bool _isSelectingRate = false;
  double? _hoveredRate;
  late double _displayRate;
  late bool _displayHasExplicitSelection;

  @override
  double get hoverMenuWidth => context.appOverlayTokens.menuWidthSm;

  @override
  double get hoverMenuHeight =>
      (kMoviePlayerPlaybackRates.length *
          context.appOverlayTokens.menuItemHeight) +
      (context.appOverlayTokens.menuVerticalPadding * 2);

  @override
  bool get canOpenHoverMenu => !_isSelectingRate;

  @override
  void onHoverMenuClosed() => _hoveredRate = null;

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
      rebuildHoverMenuOverlay();
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
        removeHoverMenu(notify: false);
        setState(() {
          _isSelectingRate = false;
        });
      } else {
        removeHoverMenu(notify: false);
      }
    }
  }

  @override
  Widget buildHoverMenu(BuildContext context) {
    return _MoviePlayerSpeedMenu(
      currentRate: _displayRate,
      hoveredRate: _hoveredRate,
      onHoveredRateChanged: (rate) {
        if (_hoveredRate == rate) {
          return;
        }
        _hoveredRate = rate;
        rebuildHoverMenuOverlay();
      },
      onRateSelected: _handleRateSelected,
    );
  }

  @override
  Widget buildHoverMenuButtonContent(BuildContext context) {
    final label = _displayHasExplicitSelection
        ? formatMoviePlayerPlaybackRateLabel(_displayRate)
        : AppLocalizations.of(context).widgetMoviePlayerSpeed;
    return Text(
      label,
      key: const Key('movie-player-speed-button'),
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s14,
        tone: AppTextTone.onMedia,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => buildHoverMenuButton(context);
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
    final overlayTokens = context.appOverlayTokens;

    return AppGlassSurface(
      key: const Key('movie-player-speed-menu'),
      tone: AppGlassTone.overlay,
      width: overlayTokens.menuWidthSm,
      padding: EdgeInsets.symmetric(
        vertical: overlayTokens.menuVerticalPadding,
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
    final label = formatMoviePlayerPlaybackRateLabel(rate);
    final backgroundColor = hovered
        ? context.appTextPalette.onMedia.withValues(
            alpha: overlayTokens.hoverAlpha,
          )
        : null;
    final rateKey = _rateKey(rate);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: KeyedSubtree(
          key: Key('movie-player-speed-menu-item-$rateKey'),
          child: MoviePlayerMenuItemRow(
            label: label,
            selected: selected,
            checkColor: resolveAppTextToneColor(context, AppTextTone.accent),
            labelKey: Key('movie-player-speed-menu-item-label-$rateKey'),
            checkKey: Key('movie-player-speed-menu-item-check-$rateKey'),
            checkSlotKey: Key(
              'movie-player-speed-menu-item-check-slot-$rateKey',
            ),
            background: backgroundColor,
          ),
        ),
      ),
    );
  }
}

/// 播放速率 label 格式化: 0.5x / 1.0x / 1.75x。
///
/// 供 speed 按钮 / surface 的桌面 pill / 移动抽屉共用。
String formatMoviePlayerPlaybackRateLabel(double rate) {
  final hundredths = (rate * 100).round();
  if (hundredths % 100 == 0 || hundredths % 50 == 0) {
    return '${rate.toStringAsFixed(1)}x';
  }
  return '${rate.toStringAsFixed(2)}x';
}

String _rateKey(double rate) => rate.toString().replaceAll('.', '_');
