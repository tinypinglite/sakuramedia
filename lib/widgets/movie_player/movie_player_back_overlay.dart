import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class MoviePlayerBackButton extends StatelessWidget {
  const MoviePlayerBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;

    return Material(
      color: context.appColors.mediaOverlayStrong,
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
