import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_hover_menu.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_menu_widgets.dart';

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

class _MoviePlayerSubtitleButtonState extends State<MoviePlayerSubtitleButton>
    with MoviePlayerHoverMenuStateMixin<MoviePlayerSubtitleButton> {
  bool _isSelectingSubtitle = false;
  late MoviePlayerSubtitleState _subtitleState;
  late bool _isApplying;

  @override
  double get hoverMenuWidth => context.appOverlayTokens.menuWidthMd;

  @override
  double get hoverMenuHeight =>
      (_effectiveMenuItemCount * context.appOverlayTokens.menuItemHeight) +
      (context.appOverlayTokens.menuVerticalPadding * 2);

  int get _effectiveMenuItemCount =>
      _subtitleState.options.isEmpty ? 1 : _subtitleState.options.length;

  @override
  bool get canOpenHoverMenu => !_isSelectingSubtitle && !_isApplying;

  @override
  Key? get hoverMenuButtonTapKey => const Key('movie-player-subtitle-button');

  @override
  Rect resolveHoverMenuHitRect(Rect menuRect, Rect buttonRect) {
    final overlayTokens = context.appOverlayTokens;
    return Rect.fromLTRB(
      menuRect.left,
      menuRect.top - overlayTokens.menuItemHeight,
      menuRect.right,
      buttonRect.top > menuRect.bottom ? buttonRect.top : menuRect.bottom,
    );
  }

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
    rebuildHoverMenuOverlay();
  }

  @override
  void dispose() {
    widget.subtitleStateListenable.removeListener(_handleSubtitleStateChanged);
    widget.isApplyingListenable.removeListener(_handleApplyingStateChanged);
    super.dispose();
  }

  void _handleSubtitleStateChanged() {
    _subtitleState = widget.subtitleStateListenable.value;
    refreshHoverMenuGeometry();
    rebuildHoverMenuOverlay();
    if (mounted) {
      setState(() {});
    }
  }

  void _handleApplyingStateChanged() {
    _isApplying = widget.isApplyingListenable.value;
    if (_isApplying) {
      removeHoverMenu();
    } else {
      rebuildHoverMenuOverlay();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _handleSubtitleSelected(int subtitleId) async {
    if (!canOpenHoverMenu) {
      return;
    }
    setState(() {
      _isSelectingSubtitle = true;
    });
    try {
      await widget.onSubtitleSelected(subtitleId);
    } finally {
      if (mounted) {
        removeHoverMenu(notify: false);
        setState(() {
          _isSelectingSubtitle = false;
        });
      } else {
        removeHoverMenu(notify: false);
      }
    }
  }

  @override
  Widget buildHoverMenu(BuildContext context) {
    return _MoviePlayerSubtitleMenu(
      options: _subtitleState.options,
      selectedSubtitleId: _subtitleState.selectedSubtitleId,
      onSubtitleSelected: _handleSubtitleSelected,
    );
  }

  @override
  Widget buildHoverMenuButtonContent(BuildContext context) {
    return Text(
      AppLocalizations.of(context).widgetMoviePlayerSubtitle,
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

class _MoviePlayerSubtitleMenu extends StatelessWidget {
  const _MoviePlayerSubtitleMenu({
    required this.options,
    required this.selectedSubtitleId,
    required this.onSubtitleSelected,
  });

  final List<MoviePlayerSubtitleOption> options;
  final int? selectedSubtitleId;
  final ValueChanged<int> onSubtitleSelected;

  @override
  Widget build(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;
    final hasOptions = options.isNotEmpty;

    return AppSurface(
      key: const Key('movie-player-subtitle-menu'),
      width: overlayTokens.menuWidthMd,
      role: AppSurfaceRole.popover,
      padding: EdgeInsets.symmetric(
        vertical: overlayTokens.menuVerticalPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: hasOptions
            ? options
                  .map(
                    (option) => _MoviePlayerSubtitleMenuItem(
                      subtitleId: option.subtitleId,
                      label: option.label,
                      selected: selectedSubtitleId == option.subtitleId,
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
          AppLocalizations.of(context).widgetMoviePlayerNoSubtitle,
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
    required this.onTap,
  });

  final int subtitleId;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppInteractiveSurface(
      key: Key('movie-player-subtitle-menu-item-$subtitleId'),
      onTap: onTap,
      focusRingRadius: context.appRadius.smBorder,
      child: MoviePlayerMenuItemRow(
        label: label,
        selected: selected,
        checkColor: resolveAppTextToneColor(context, AppTextTone.accent),
        labelKey: Key('movie-player-subtitle-menu-item-label-$subtitleId'),
        checkKey: Key('movie-player-subtitle-menu-item-check-$subtitleId'),
        checkSlotKey: Key(
          'movie-player-subtitle-menu-item-check-slot-$subtitleId',
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}
