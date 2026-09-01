import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 媒体封面居中的播放入口。
///
/// 作为 [Stack] 的子节点使用；点击只命中圆形图标区域，其他位置仍交给封面自身处理。
class MediaCenterPlayButton extends StatelessWidget {
  const MediaCenterPlayButton({super.key, required this.onTap, this.buttonKey});

  final VoidCallback onTap;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final iconSize = context.appComponentTokens.iconSize4xl;
    final padding = context.appSpacing.xs;
    final diameter = iconSize + padding * 2;

    return Positioned.fill(
      child: Center(
        child: SizedBox.square(
          dimension: diameter,
          child: ClipOval(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: buttonKey,
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    size: iconSize,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
