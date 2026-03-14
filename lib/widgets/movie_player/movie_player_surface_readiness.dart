import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class MoviePlayerSurfaceReadiness extends ChangeNotifier {
  bool _isReady = false;

  bool get isReady => _isReady;

  void markReady() {
    if (_isReady) {
      return;
    }

    _isReady = true;
    notifyListeners();
  }

  void reset() {
    if (!_isReady) {
      return;
    }

    _isReady = false;
    notifyListeners();
  }
}

class MoviePlayerSurfaceFrame extends StatelessWidget {
  const MoviePlayerSurfaceFrame({
    super.key,
    required this.isReady,
    required this.child,
  });

  final bool isReady;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = context.appColors.movieDetailHeroBackgroundStart;

    return ColoredBox(
      color: backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (!isReady)
            Positioned.fill(
              child: ColoredBox(
                key: const Key('movie-player-surface-ready-mask'),
                color: backgroundColor,
              ),
            ),
        ],
      ),
    );
  }
}
