import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

enum AppToastTone { neutral, success, warning, error, info }

class AppGlassToast extends StatelessWidget {
  const AppGlassToast({
    super.key,
    required this.message,
    this.tone = AppToastTone.neutral,
  });

  final String message;
  final AppToastTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appToastTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final content = _buildContent(context);
    final padding = EdgeInsets.symmetric(
      horizontal: tokens.horizontalPadding,
      vertical: tokens.verticalPadding,
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.horizontalScreenInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: tokens.maxWidth,
          minWidth: tokens.minWidth,
          minHeight: tokens.minHeight,
        ),
        child: highContrast
            ? _buildSolidSurface(
                context,
                padding: padding,
                borderRadius: tokens.borderRadiusValue,
                child: content,
              )
            : _buildGlassSurface(
                context,
                padding: padding,
                borderRadius: tokens.borderRadius,
                isDark: isDark,
                child: content,
              ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final tokens = context.appToastTokens;
    final textStyle =
        resolveAppTextStyle(
          context,
          size: AppTextSize.s16,
          weight: AppTextWeight.medium,
          tone: AppTextTone.primary,
        ).copyWith(
          fontSize: tokens.textSize,
          height: 1.35,
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        );
    final text = Text(
      message,
      textAlign: tone == AppToastTone.neutral
          ? TextAlign.center
          : TextAlign.start,
      style: textStyle,
    );
    final icon = _toneIcon;
    if (icon == null) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: tokens.maxWidth - tokens.horizontalPadding * 2,
        ),
        child: text,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(
          icon,
          size: context.appComponentTokens.iconSizeSm,
          color: _toneColor(context.appTextPalette),
        ),
        SizedBox(width: context.appSpacing.sm),
        Flexible(child: text),
      ],
    );
  }

  Widget _buildGlassSurface(
    BuildContext context, {
    required EdgeInsets padding,
    required double borderRadius,
    required bool isDark,
    required Widget child,
  }) {
    final settings =
        (isDark
                ? LiquidGlassSettings.ios27Dark
                : LiquidGlassSettings.ios27Light)
            .copyWith(
              glassColor: isDark
                  ? const Color(0xAA181618)
                  : const Color(0x9AFBFAF8),
              saturation: isDark ? 1.65 : 2,
              frost: 16,
              thickness: 34,
              shadow: isDark
                  ? null
                  : <BoxShadow>[
                      BoxShadow(
                        color: context.appShadows.color.withValues(alpha: 0.10),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
            );
    final shape = BorderRadius.circular(borderRadius);
    final highlight = isDark
        ? const Color(0x26FFFFFF)
        : const Color(0x6BFFFFFF);
    final shade = isDark
        ? const Color(0x24000000)
        : context.appShadows.color.withValues(alpha: 0.045);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark ? const Color(0x59000000) : const Color(0x1A1F1A18),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: GlassContainer(
        useOwnLayer: true,
        quality: GlassQuality.standard,
        clipBehavior: Clip.antiAlias,
        shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
        settings: settings,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: shape,
                    border: Border.all(
                      color: isDark
                          ? const Color(0x2EFFFFFF)
                          : const Color(0x80FFFFFF),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        highlight,
                        highlight.withValues(alpha: 0),
                        shade,
                      ],
                      stops: const <double>[0, 0.42, 1],
                    ),
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildSolidSurface(
    BuildContext context, {
    required EdgeInsets padding,
    required BorderRadius borderRadius,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surfaceElevated,
        borderRadius: borderRadius,
        border: Border.all(color: context.appColors.borderStrong),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.appShadows.color.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  IconData? get _toneIcon {
    return switch (tone) {
      AppToastTone.neutral => null,
      AppToastTone.success => Icons.check_rounded,
      AppToastTone.warning => Icons.warning_amber_rounded,
      AppToastTone.error => Icons.error_outline_rounded,
      AppToastTone.info => Icons.info_outline_rounded,
    };
  }

  Color _toneColor(AppTextPalette palette) {
    return switch (tone) {
      AppToastTone.neutral => palette.primary,
      AppToastTone.success => palette.success,
      AppToastTone.warning => palette.warning,
      AppToastTone.error => palette.error,
      AppToastTone.info => palette.info,
    };
  }
}
