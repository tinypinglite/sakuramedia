import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';
import 'package:sakuramedia/widgets/base/media/video/sakura_desktop_video_controls.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_anchored_menu.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_menu_widgets.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_subtitle_settings.dart';

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
  final AppGlassAnchoredMenuController _menuController =
      AppGlassAnchoredMenuController();

  SakuraDesktopVideoControlsOverlayLockScope? _overlayLockScope;
  bool _holdsOverlayLock = false;
  bool _isSelectingSubtitle = false;
  late bool _isApplying;

  bool get _canOpenMenu => !_isSelectingSubtitle && !_isApplying;

  @override
  void initState() {
    super.initState();
    _isApplying = widget.isApplyingListenable.value;
    widget.isApplyingListenable.addListener(_handleApplyingStateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _overlayLockScope = SakuraDesktopVideoControlsOverlayLockScope.maybeOf(
      context,
    );
  }

  @override
  void didUpdateWidget(covariant MoviePlayerSubtitleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isApplyingListenable != widget.isApplyingListenable) {
      oldWidget.isApplyingListenable.removeListener(
        _handleApplyingStateChanged,
      );
      _isApplying = widget.isApplyingListenable.value;
      widget.isApplyingListenable.addListener(_handleApplyingStateChanged);
    }
  }

  @override
  void dispose() {
    _releaseOverlayLock();
    widget.isApplyingListenable.removeListener(_handleApplyingStateChanged);
    super.dispose();
  }

  void _handleApplyingStateChanged() {
    _isApplying = widget.isApplyingListenable.value;
    if (_isApplying) {
      _menuController.close();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _handleMenuOpen() {
    if (_holdsOverlayLock) {
      return;
    }
    _overlayLockScope?.acquire();
    _holdsOverlayLock = _overlayLockScope != null;
  }

  void _handleMenuClose() {
    _releaseOverlayLock();
  }

  void _releaseOverlayLock() {
    if (!_holdsOverlayLock) {
      return;
    }
    _holdsOverlayLock = false;
    _overlayLockScope?.release();
  }

  Future<void> _handleSubtitleSelected(int subtitleId) async {
    if (!_canOpenMenu) {
      return;
    }
    setState(() {
      _isSelectingSubtitle = true;
    });
    try {
      await widget.onSubtitleSelected(subtitleId);
    } finally {
      _menuController.close();
      if (mounted) {
        setState(() {
          _isSelectingSubtitle = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;
    return AppGlassAnchoredMenu(
      controller: _menuController,
      panelKey: const Key('movie-player-subtitle-menu'),
      width: overlayTokens.playerSubtitleMenuWidth,
      minWidth: overlayTokens.menuWidthMd,
      maxWidth: overlayTokens.playerSubtitleMenuWidth,
      surfaceStyle: AppSurfaceStyle.flat,
      estimatedHeight: context.appFormTokens.menuMaxHeight,
      maxHeight: context.appFormTokens.menuMaxHeight,
      gap: overlayTokens.menuGap,
      onOpen: _handleMenuOpen,
      onClose: _handleMenuClose,
      triggerBuilder: (context, isOpen, toggle) {
        return AppInteractiveSurface(
          key: const Key('movie-player-subtitle-button'),
          enabled: _canOpenMenu,
          onTap: _canOpenMenu ? toggle : null,
          child: Container(
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
              AppLocalizations.of(context).widgetMoviePlayerSubtitle,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                tone: isOpen ? AppTextTone.accent : AppTextTone.onMedia,
              ),
            ),
          ),
        );
      },
      contentBuilder: (context, close) {
        return _MoviePlayerSubtitleMenuContent(
          subtitleStateListenable: widget.subtitleStateListenable,
          isApplyingListenable: widget.isApplyingListenable,
          onSubtitleSelected: _handleSubtitleSelected,
        );
      },
    );
  }
}

class _MoviePlayerSubtitleMenuContent extends StatefulWidget {
  const _MoviePlayerSubtitleMenuContent({
    required this.subtitleStateListenable,
    required this.isApplyingListenable,
    required this.onSubtitleSelected,
  });

  final ValueListenable<MoviePlayerSubtitleState> subtitleStateListenable;
  final ValueListenable<bool> isApplyingListenable;
  final ValueChanged<int> onSubtitleSelected;

  @override
  State<_MoviePlayerSubtitleMenuContent> createState() =>
      _MoviePlayerSubtitleMenuContentState();
}

class _MoviePlayerSubtitleMenuContentState
    extends State<_MoviePlayerSubtitleMenuContent> {
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;
    final verticalPadding = EdgeInsets.symmetric(
      vertical: overlayTokens.menuVerticalPadding,
    );
    if (_showSettings) {
      return Padding(
        padding: verticalPadding,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.appSpacing.md),
          child: MoviePlayerSubtitleSettingsView(
            onBack: () => setState(() => _showSettings = false),
          ),
        ),
      );
    }

    return Padding(
      padding: verticalPadding,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          widget.subtitleStateListenable,
          widget.isApplyingListenable,
        ]),
        builder: (context, child) {
          final subtitleState = widget.subtitleStateListenable.value;
          final isApplying = widget.isApplyingListenable.value;
          final hasOptions = subtitleState.options.isNotEmpty;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasOptions)
                ...subtitleState.options.map(
                  (option) => _MoviePlayerSubtitleMenuItem(
                    subtitleId: option.subtitleId,
                    label: option.label,
                    selected:
                        subtitleState.selectedSubtitleId == option.subtitleId,
                    enabled: !isApplying,
                    onTap: () => widget.onSubtitleSelected(option.subtitleId),
                  ),
                )
              else
                const _MoviePlayerSubtitleEmptyItem(),
              Divider(
                height: overlayTokens.menuItemHeight / 2,
                color: context.appColors.divider,
              ),
              AppInteractiveSurface(
                key: const Key('movie-player-subtitle-menu-settings'),
                enabled: !isApplying,
                onTap: () => setState(() => _showSettings = true),
                focusRingRadius: context.appRadius.smBorder,
                child: MoviePlayerMenuItemRow(
                  label: AppLocalizations.of(
                    context,
                  ).moviePlayerSubtitleSettingsTitle,
                  selected: false,
                  checkColor: resolveAppTextToneColor(
                    context,
                    AppTextTone.accent,
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: overlayTokens.controlCheckIconSize,
                    color: context.appTextPalette.secondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );
        },
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
    required this.enabled,
    required this.onTap,
  });

  final int subtitleId;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppInteractiveSurface(
      key: Key('movie-player-subtitle-menu-item-$subtitleId'),
      enabled: enabled,
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
