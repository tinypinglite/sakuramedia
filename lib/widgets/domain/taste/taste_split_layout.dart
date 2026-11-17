import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 口味面板的双栏布局：宽度达到 640 时左右并排，否则上下堆叠。
class TasteSplitLayout extends StatelessWidget {
  const TasteSplitLayout({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryFlex = 1,
    this.secondaryFlex = 1,
  });

  final Widget primary;
  final Widget secondary;
  final int primaryFlex;
  final int secondaryFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _twoColumnMinWidth) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: primaryFlex, child: primary),
                VerticalDivider(
                  width: context.appSpacing.lg,
                  thickness: 1,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                ),
                Expanded(flex: secondaryFlex, child: secondary),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            primary,
            SizedBox(height: context.appSpacing.lg),
            secondary,
          ],
        );
      },
    );
  }
}

const double _twoColumnMinWidth = 640;
