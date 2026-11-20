import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 封面底部的观看进度条；画在卡片最底边，不参与点击。
class AppCoverProgressBar extends StatelessWidget {
  const AppCoverProgressBar({
    super.key,
    required this.ratio,
    this.height,
    this.fillKey,
  });

  final double ratio;

  /// 进度条高度；默认取半档小间距。
  final double? height;

  /// 进度填充块的测试锚点。
  final Key? fillKey;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final trackColor = context.appTextPalette.onMedia.withValues(alpha: 0.24);
    return IgnorePointer(
      child: SizedBox(
        height: height ?? spacing.xs / 2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: trackColor),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: ratio.clamp(0, 1),
                // ColoredBox 无 child 时按 constraints.smallest 取尺寸；
                // 不给 heightFactor 会把高度压成 0。
                heightFactor: 1,
                child: ColoredBox(
                  key: fillKey,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
