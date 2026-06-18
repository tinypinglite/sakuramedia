import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_player/movie_player_back_overlay.dart';

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
    this.onBackPressed,
  });

  final bool isReady;
  final Widget child;

  /// 首帧未到、黑蒙版盖住 media_kit 控制层（含其自带的返回按钮）期间，在蒙版之上
  /// 叠一个独立返回按钮兜底；为 `null` 时不叠。就绪后蒙版与该按钮一并消失。
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = context.appColors.movieDetailHeroBackgroundStart;
    final onBackPressed = this.onBackPressed;

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
          if (!isReady && onBackPressed != null)
            MoviePlayerBackOverlay(onPressed: onBackPressed),
        ],
      ),
    );
  }
}
