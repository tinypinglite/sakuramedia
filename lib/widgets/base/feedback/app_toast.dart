import 'package:flutter/widgets.dart';
import 'package:oktoast/oktoast.dart';

import 'app_glass_toast.dart';

export 'package:oktoast/oktoast.dart' show dismissAllToast;
export 'app_glass_toast.dart' show AppGlassToast, AppToastTone;

const Duration kAppToastDuration = Duration(seconds: 3);
const Duration kAppToastAnimationDuration = Duration(milliseconds: 180);

void showToast(
  String message, {
  BuildContext? context,
  AppToastTone tone = AppToastTone.neutral,
  Duration? duration,
}) {
  showToastWidget(
    AppGlassToast(message: message, tone: tone),
    context: context,
    duration: duration ?? kAppToastDuration,
    position: ToastPosition.center,
    animationDuration: kAppToastAnimationDuration,
    animationCurve: Curves.easeOutCubic,
    animationBuilder: _buildToastAnimation,
  );
}

Widget _buildToastAnimation(
  BuildContext context,
  Widget child,
  AnimationController controller,
  double percent,
) {
  final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations;
  final opacity = percent.clamp(0.0, 1.0);
  final scale = disableAnimations ?? false
      ? 1.0
      : 0.97 + 0.03 * Curves.easeOutCubic.transform(opacity);
  return Opacity(
    opacity: opacity,
    child: Transform.scale(scale: scale, child: child),
  );
}
