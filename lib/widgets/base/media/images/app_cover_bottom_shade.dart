import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 封面底部渐变遮罩(用 [mediaOverlaySoft] → [mediaOverlayStrong] 从中间往下加深),
/// 保证浮层白字与图标可读。全程 [IgnorePointer] 包裹,不吃点击。
///
/// 卡片默认 stops `[0.45, 0.72, 1]`; actor 卡稍强一点用 `[0.42, 0.7, 1]`。
class AppCoverBottomShade extends StatelessWidget {
  const AppCoverBottomShade({
    super.key,
    this.stops = const [0.45, 0.72, 1],
  });

  final List<double> stops;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.mediaOverlaySoft.withValues(alpha: 0),
              colors.mediaOverlaySoft,
              colors.mediaOverlayStrong,
            ],
            stops: stops,
          ),
        ),
      ),
    );
  }
}
