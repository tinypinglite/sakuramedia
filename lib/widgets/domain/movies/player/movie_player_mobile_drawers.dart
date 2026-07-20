import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_menu_widgets.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_playback_info.dart';
import 'package:sakuramedia/widgets/domain/movies/player/movie_player_speed_button.dart';

enum MoviePlayerMobileDrawerType { speed, subtitle }

class MoviePlayerMobileSpeedDisplayState {
  const MoviePlayerMobileSpeedDisplayState({
    required this.rate,
    required this.hasExplicitSelection,
  });

  final double rate;
  final bool hasExplicitSelection;

  MoviePlayerMobileSpeedDisplayState copyWith({
    double? rate,
    bool? hasExplicitSelection,
  }) {
    return MoviePlayerMobileSpeedDisplayState(
      rate: rate ?? this.rate,
      hasExplicitSelection: hasExplicitSelection ?? this.hasExplicitSelection,
    );
  }
}

const Duration _moviePlayerMobileDrawerAnimationDuration = Duration(
  milliseconds: 220,
);
const String _moviePlayerMobileNoSubtitleLabel = '无可用字幕';

List<Widget> buildMoviePlayerMobileDrawerToggleButtons({
  required MoviePlayerMobileDrawerType? activeDrawer,
  required ValueListenable<MoviePlayerMobileSpeedDisplayState>
      speedDisplayListenable,
  required VoidCallback onSpeedButtonPressed,
  required VoidCallback onSubtitleButtonPressed,
}) {
  return <Widget>[
    _MoviePlayerMobileSpeedDrawerToggleButton(
      buttonKey: const Key('movie-player-mobile-speed-button'),
      speedDisplayListenable: speedDisplayListenable,
      active: activeDrawer == MoviePlayerMobileDrawerType.speed,
      onTap: onSpeedButtonPressed,
    ),
    _MoviePlayerMobileDrawerToggleButton(
      key: const Key('movie-player-mobile-subtitle-button'),
      label: '字幕',
      active: activeDrawer == MoviePlayerMobileDrawerType.subtitle,
      onTap: onSubtitleButtonPressed,
    ),
  ];
}

/// 播放器右侧滑入抽屉的公用外壳:
///   IgnorePointer > GestureDetector(dismiss) > Align.centerRight
///     > Padding(horizontal inset) > GestureDetector(吞点击) > child
/// child 一般是 AnimatedSwitcher(SlideTransition 右侧滑入)。
Widget _moviePlayerBuildSideDrawerHost({
  required BuildContext context,
  required Key layerKey,
  required Key dismissAreaKey,
  required bool ignoring,
  required VoidCallback onDismiss,
  required Widget child,
}) {
  final overlayTokens = context.appOverlayTokens;
  return IgnorePointer(
    key: layerKey,
    ignoring: ignoring,
    child: GestureDetector(
      key: dismissAreaKey,
      behavior: HitTestBehavior.opaque,
      onTap: onDismiss,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: overlayTokens.playerDrawerHorizontalInset,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: child,
          ),
        ),
      ),
    ),
  );
}

Widget _moviePlayerSideDrawerAnimatedSwitcher({required Widget child}) {
  return AnimatedSwitcher(
    duration: _moviePlayerMobileDrawerAnimationDuration,
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) {
      final offsetAnimation = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(animation);
      return SlideTransition(position: offsetAnimation, child: child);
    },
    child: child,
  );
}

Widget buildMoviePlayerMobileDrawerOverlay({
  required BuildContext context,
  required MoviePlayerMobileDrawerType? activeDrawer,
  required MoviePlayerSubtitleState subtitleState,
  required double currentRate,
  required ValueListenable<bool> isApplyingSubtitleListenable,
  required VoidCallback onDismiss,
  required Future<void> Function(double rate) onRateSelected,
  required Future<void> Function(int subtitleId) onSubtitleSelected,
}) {
  return _moviePlayerBuildSideDrawerHost(
    context: context,
    layerKey: const Key('movie-player-mobile-drawer-layer'),
    dismissAreaKey: const Key('movie-player-mobile-drawer-dismiss-area'),
    ignoring: activeDrawer == null,
    onDismiss: onDismiss,
    child: _moviePlayerSideDrawerAnimatedSwitcher(
      child: switch (activeDrawer) {
        MoviePlayerMobileDrawerType.speed => _MoviePlayerMobileSpeedDrawer(
            key: const ValueKey<String>(
              'movie-player-mobile-speed-drawer',
            ),
            currentRate: currentRate,
            onRateSelected: onRateSelected,
          ),
        MoviePlayerMobileDrawerType.subtitle =>
          _MoviePlayerMobileSubtitleDrawer(
            key: const ValueKey<String>(
              'movie-player-mobile-subtitle-drawer',
            ),
            subtitleState: subtitleState,
            isApplyingSubtitleListenable: isApplyingSubtitleListenable,
            onSubtitleSelected: onSubtitleSelected,
          ),
        null => const SizedBox.shrink(
            key: ValueKey<String>('movie-player-mobile-drawer-closed'),
          ),
      },
    ),
  );
}

Widget buildMoviePlayerInfoSideDrawerOverlay({
  required BuildContext context,
  required bool isOpen,
  required VoidCallback onDismiss,
  required ValueListenable<MoviePlayerPlaybackInfoSnapshot> infoListenable,
  MoviePlayerMediaInfo? mediaInfo,
}) {
  return _moviePlayerBuildSideDrawerHost(
    context: context,
    layerKey: const Key('movie-player-info-side-drawer-layer'),
    dismissAreaKey: const Key('movie-player-info-side-drawer-dismiss-area'),
    ignoring: !isOpen,
    onDismiss: onDismiss,
    child: _moviePlayerSideDrawerAnimatedSwitcher(
      child: isOpen
          ? _MoviePlayerInfoSideDrawer(
              key: const ValueKey<String>('movie-player-info-side-drawer'),
              infoListenable: infoListenable,
              mediaInfo: mediaInfo,
            )
          : const SizedBox.shrink(
              key: ValueKey<String>(
                'movie-player-info-side-drawer-closed',
              ),
            ),
    ),
  );
}

class _MoviePlayerMobileDrawerToggleButton extends StatelessWidget {
  const _MoviePlayerMobileDrawerToggleButton({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
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
          label,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            tone: active ? AppTextTone.accent : AppTextTone.onMedia,
          ),
        ),
      ),
    );
  }
}

class _MoviePlayerMobileSpeedDrawerToggleButton extends StatelessWidget {
  const _MoviePlayerMobileSpeedDrawerToggleButton({
    required this.buttonKey,
    required this.speedDisplayListenable,
    required this.active,
    required this.onTap,
  });

  final Key buttonKey;
  final ValueListenable<MoviePlayerMobileSpeedDisplayState>
      speedDisplayListenable;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MoviePlayerMobileSpeedDisplayState>(
      valueListenable: speedDisplayListenable,
      builder: (context, speedDisplay, child) {
        final showsRateLabel = speedDisplay.hasExplicitSelection ||
            (speedDisplay.rate - 1.0).abs() >= 0.001;
        final label = showsRateLabel
            ? formatMoviePlayerPlaybackRateLabel(speedDisplay.rate)
            : '倍速';
        return _MoviePlayerMobileDrawerToggleButton(
          key: buttonKey,
          label: label,
          active: active,
          onTap: onTap,
        );
      },
    );
  }
}

class _MoviePlayerMobileDrawerSurface extends StatelessWidget {
  const _MoviePlayerMobileDrawerSurface({
    required this.child,
    // ignore: unused_element_parameter
    this.width,
  });

  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final overlayTokens = context.appOverlayTokens;
    return Container(
      width: width ?? overlayTokens.playerDrawerWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: colors.movieDetailHeroBackgroundStart.withValues(
          alpha: overlayTokens.drawerSurfaceAlpha,
        ),
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(overlayTokens.surfaceRadius),
        ),
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
      child: child,
    );
  }
}

class _MoviePlayerMobileSpeedDrawer extends StatelessWidget {
  const _MoviePlayerMobileSpeedDrawer({
    super.key,
    required this.currentRate,
    required this.onRateSelected,
  });

  final double currentRate;
  final Future<void> Function(double rate) onRateSelected;

  @override
  Widget build(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;
    final selectedColor = resolveAppTextToneColor(context, AppTextTone.accent);
    return _MoviePlayerMobileDrawerSurface(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: overlayTokens.drawerVerticalPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: kMoviePlayerPlaybackRates.map((rate) {
            final selected = (currentRate - rate).abs() < 0.001;
            final rateKey = rate.toString().replaceAll('.', '_');
            return GestureDetector(
              key: Key('movie-player-mobile-speed-drawer-item-$rateKey'),
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(onRateSelected(rate)),
              child: MoviePlayerMenuItemRow(
                label: formatMoviePlayerPlaybackRateLabel(rate),
                selected: selected,
                checkColor: selectedColor,
                checkKey: Key(
                  'movie-player-mobile-speed-drawer-item-check-$rateKey',
                ),
                checkSlotKey: Key(
                  'movie-player-mobile-speed-drawer-item-check-slot-$rateKey',
                ),
              ),
            );
          }).toList(growable: false),
        ),
      ),
    );
  }
}

class _MoviePlayerInfoSideDrawer extends StatelessWidget {
  const _MoviePlayerInfoSideDrawer({
    super.key,
    required this.infoListenable,
    this.mediaInfo,
  });

  final ValueListenable<MoviePlayerPlaybackInfoSnapshot> infoListenable;
  final MoviePlayerMediaInfo? mediaInfo;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final overlayTokens = context.appOverlayTokens;
    return Container(
      width: overlayTokens.playerInfoDrawerWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: colors.surfaceMuted.withValues(
          alpha: overlayTokens.infoDrawerSurfaceAlpha,
        ),
        borderRadius: BorderRadius.horizontal(
          left: Radius.circular(overlayTokens.surfaceRadius),
        ),
        border: Border.all(
          color: context.appTextPalette.onMedia.withValues(
            alpha: overlayTokens.infoDrawerSurfaceAlpha / 2,
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
      child: Padding(
        padding: EdgeInsets.all(context.appSpacing.md),
        child: MoviePlayerPlaybackInfoPanel(
          infoListenable: infoListenable,
          mediaInfo: mediaInfo,
        ),
      ),
    );
  }
}

class _MoviePlayerMobileSubtitleDrawer extends StatelessWidget {
  const _MoviePlayerMobileSubtitleDrawer({
    super.key,
    required this.subtitleState,
    required this.isApplyingSubtitleListenable,
    required this.onSubtitleSelected,
  });

  final MoviePlayerSubtitleState subtitleState;
  final ValueListenable<bool> isApplyingSubtitleListenable;
  final Future<void> Function(int subtitleId) onSubtitleSelected;

  @override
  Widget build(BuildContext context) {
    final options = subtitleState.options;
    final overlayTokens = context.appOverlayTokens;
    final selectedColor = Theme.of(context).colorScheme.primary;
    return _MoviePlayerMobileDrawerSurface(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: overlayTokens.drawerVerticalPadding,
        ),
        child: ValueListenableBuilder<bool>(
          valueListenable: isApplyingSubtitleListenable,
          builder: (context, isApplyingSubtitle, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: options.isEmpty
                  ? <Widget>[
                      SizedBox(
                        key: const Key(
                          'movie-player-mobile-subtitle-drawer-empty',
                        ),
                        height: overlayTokens.menuItemHeight,
                        child: Center(
                          child: Text(
                            _moviePlayerMobileNoSubtitleLabel,
                            style: resolveAppTextStyle(
                              context,
                              size: AppTextSize.s14,
                              tone: AppTextTone.muted,
                            ),
                          ),
                        ),
                      ),
                    ]
                  : options.map((option) {
                      final selected = subtitleState.selectedSubtitleId ==
                          option.subtitleId;
                      return GestureDetector(
                        key: Key(
                          'movie-player-mobile-subtitle-drawer-item-${option.subtitleId}',
                        ),
                        behavior: HitTestBehavior.opaque,
                        onTap: isApplyingSubtitle
                            ? null
                            : () => unawaited(
                                  onSubtitleSelected(option.subtitleId),
                                ),
                        child: MoviePlayerMenuItemRow(
                          label: option.label,
                          selected: selected,
                          checkColor: selectedColor,
                          checkKey: Key(
                            'movie-player-mobile-subtitle-drawer-item-check-${option.subtitleId}',
                          ),
                          checkSlotKey: Key(
                            'movie-player-mobile-subtitle-drawer-item-check-slot-${option.subtitleId}',
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }).toList(growable: false),
            );
          },
        ),
      ),
    );
  }
}
