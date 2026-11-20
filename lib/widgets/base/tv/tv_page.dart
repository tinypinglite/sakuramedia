import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

class TvPageBackground extends StatelessWidget {
  const TvPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surfacePage,
            colors.movieDetailHeroBackgroundEnd,
            colors.surfacePage,
          ],
        ),
      ),
      child: child,
    );
  }
}

class TvPagePadding extends StatelessWidget {
  const TvPagePadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTvTokens.safeHorizontal,
        vertical: AppTvTokens.safeVertical,
      ),
      child: child,
    );
  }
}

class TvPageHeader extends StatelessWidget {
  const TvPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s48,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              if (subtitle case final subtitle?) ...[
                SizedBox(height: context.appSpacing.sm),
                Text(
                  subtitle,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s20,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing case final trailing?) trailing,
      ],
    );
  }
}
