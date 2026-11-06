import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';

enum AppButtonContentSize { large, medium, small, xSmall, xxSmall }

typedef AppButtonContentMetrics = (
  double height,
  double horizontalPadding,
  double gap,
  double iconSize,
  AppTextSize textSize,
);

AppButtonContentMetrics resolveAppButtonContentMetrics(
  BuildContext context,
  AppButtonContentSize size,
) {
  final tokens = context.appComponentTokens;
  return switch (size) {
    AppButtonContentSize.large => (
      tokens.buttonHeightLg,
      tokens.buttonHorizontalPaddingMd,
      tokens.buttonGapMd,
      tokens.iconSizeSm,
      AppTextSize.s14,
    ),
    AppButtonContentSize.medium => (
      tokens.buttonHeightMd,
      tokens.buttonHorizontalPaddingMd,
      tokens.buttonGapMd,
      tokens.iconSizeSm,
      AppTextSize.s14,
    ),
    AppButtonContentSize.small => (
      tokens.buttonHeightSm,
      tokens.buttonHorizontalPaddingSm,
      tokens.buttonGapSm,
      tokens.iconSizeSm,
      AppTextSize.s14,
    ),
    AppButtonContentSize.xSmall => (
      tokens.buttonHeightXs,
      tokens.buttonHorizontalPaddingXs,
      tokens.buttonGapXs,
      tokens.iconSizeXs,
      AppTextSize.s12,
    ),
    AppButtonContentSize.xxSmall => (
      tokens.buttonHeight2xs,
      tokens.buttonHorizontalPadding2xs,
      tokens.buttonGap2xs,
      tokens.iconSize2xs,
      AppTextSize.s10,
    ),
  };
}

Widget buildAppButtonContent({
  required String label,
  required TextStyle labelStyle,
  required double iconSize,
  required double gap,
  required Color iconColor,
  required bool isLoading,
  Key? labelKey,
  Widget? icon,
  Widget? trailingIcon,
}) {
  return IconTheme(
    data: IconThemeData(size: iconSize, color: iconColor),
    child: Row(
      spacing: gap,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          SizedBox.square(
            dimension: iconSize,
            child: AppInlineSpinner(color: iconColor),
          ),
        if (!isLoading) ?icon,
        Flexible(
          child: Text(
            key: labelKey,
            label,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        ?trailingIcon,
      ],
    ),
  );
}
