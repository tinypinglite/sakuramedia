import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

class MovieDetailSection extends StatelessWidget {
  const MovieDetailSection({
    super.key,
    required this.title,
    required this.child,
    this.titleKey,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Key? titleKey;

  /// 标题行右侧的低强调操作（如演员区块的「管理」）。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: context.appComponentTokens.movieDetailSectionGap,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  key: titleKey,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.primary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          SizedBox(
            height: context.appComponentTokens.movieDetailSectionTitleGap,
          ),
          child,
        ],
      ),
    );
  }
}
