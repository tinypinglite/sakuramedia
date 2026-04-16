import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class MoviePlayerBackButton extends StatelessWidget {
  const MoviePlayerBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;
    final overlayTokens = context.appOverlayTokens;

    return Material(
      type: MaterialType.transparency,
      borderRadius: context.appRadius.pillBorder,
      child: InkWell(
        key: const Key('movie-player-back-button'),
        borderRadius: context.appRadius.pillBorder,
        onTap: onPressed,
        child: SizedBox(
          width: overlayTokens.playerBackBadgeMinHeight,
          height: overlayTokens.playerBackBadgeMinHeight,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: componentTokens.iconSizeSm,
            color: context.appColors.textOnMedia,
          ),
        ),
      ),
    );
  }
}

class MoviePlayerInfoButton extends StatelessWidget {
  const MoviePlayerInfoButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;
    final overlayTokens = context.appOverlayTokens;
    return Tooltip(
      message: '播放信息',
      child: Material(
        type: MaterialType.transparency,
        borderRadius: context.appRadius.pillBorder,
        child: InkWell(
          key: const Key('movie-player-info-button'),
          borderRadius: context.appRadius.pillBorder,
          onTap: onPressed,
          child: SizedBox(
            width: overlayTokens.playerBackBadgeMinHeight,
            height: overlayTokens.playerBackBadgeMinHeight,
            child: Icon(
              Icons.info_outline_rounded,
              size: componentTokens.iconSizeSm,
              color: context.appColors.textOnMedia,
            ),
          ),
        ),
      ),
    );
  }
}

class MoviePlayerCurrentNumberBadge extends StatelessWidget {
  const MoviePlayerCurrentNumberBadge({super.key, required this.movieNumber});

  final String movieNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final overlayTokens = context.appOverlayTokens;
    final resolvedMovieNumber = movieNumber.trim();

    return Material(
      type: MaterialType.transparency,
      borderRadius: context.appRadius.pillBorder,
      child: Container(
        key: const Key('movie-player-current-number'),
        constraints: BoxConstraints(
          minHeight: overlayTokens.playerBackBadgeMinHeight,
          maxWidth: overlayTokens.playerBackBadgeMaxWidth,
        ),
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(
          horizontal: overlayTokens.controlTrailingGap,
        ),
        child: Text(
          resolvedMovieNumber,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colors.textOnMedia.withValues(
              alpha: overlayTokens.primaryLabelAlpha,
            ),
            fontSize: overlayTokens.controlLabelFontSize,
            fontWeight: FontWeight.w500,
            height: overlayTokens.controlLabelHeight,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }
}

class MoviePlayerBackWithNumberControl extends StatelessWidget {
  const MoviePlayerBackWithNumberControl({
    super.key,
    required this.onPressed,
    required this.movieNumber,
  });

  final VoidCallback onPressed;
  final String movieNumber;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MoviePlayerBackButton(onPressed: onPressed),
        SizedBox(width: context.appSpacing.xs / 2),
        MoviePlayerCurrentNumberBadge(movieNumber: movieNumber),
      ],
    );
  }
}

class MoviePlayerBackOverlay extends StatelessWidget {
  const MoviePlayerBackOverlay({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final overlayTokens = context.appOverlayTokens;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: overlayTokens.playerBackOverlayLeft,
          top: overlayTokens.playerBackOverlayTop,
        ),
        child: MoviePlayerBackButton(onPressed: onPressed),
      ),
    );
  }
}
