import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class MoviePlayerBackButton extends StatelessWidget {
  const MoviePlayerBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;

    return Material(
      type: MaterialType.transparency,
      borderRadius: context.appRadius.pillBorder,
      child: InkWell(
        key: const Key('movie-player-back-button'),
        borderRadius: context.appRadius.pillBorder,
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: componentTokens.iconSizeSm,
            color: Colors.white,
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
            width: 44,
            height: 44,
            child: Icon(
              Icons.info_outline_rounded,
              size: componentTokens.iconSizeSm,
              color: Colors.white,
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
    final resolvedMovieNumber = movieNumber.trim();

    return Material(
      type: MaterialType.transparency,
      borderRadius: context.appRadius.pillBorder,
      child: Container(
        key: const Key('movie-player-current-number'),
        constraints: const BoxConstraints(minHeight: 44, maxWidth: 280),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          resolvedMovieNumber,
          style: theme.textTheme.labelLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.94),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.0,
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
        const SizedBox(width: 2),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 24),
        child: MoviePlayerBackButton(onPressed: onPressed),
      ),
    );
  }
}
