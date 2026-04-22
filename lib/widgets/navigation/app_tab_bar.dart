import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/theme.dart';

enum AppTabBarVariant { auto, desktop, compact, mobileTop }

class _AppTabBarStyleSpec {
  const _AppTabBarStyleSpec({
    required this.visualTabHeight,
    required this.labelPadding,
    required this.labelStyle,
    required this.unselectedLabelStyle,
    required this.isScrollable,
    required this.tabAlignment,
    required this.dividerColor,
    required this.dividerHeight,
    required this.indicatorThickness,
  });

  final double visualTabHeight;
  final EdgeInsetsGeometry labelPadding;
  final TextStyle labelStyle;
  final TextStyle unselectedLabelStyle;
  final bool isScrollable;
  final TabAlignment tabAlignment;
  final Color dividerColor;
  final double dividerHeight;
  final double indicatorThickness;
}

class AppTabBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTabBar({
    super.key,
    required this.tabs,
    this.controller,
    this.onTap,
    this.variant = AppTabBarVariant.auto,
    this.tabHeight,
    this.indicatorSize = TabBarIndicatorSize.label,
  });

  final List<Widget> tabs;
  final TabController? controller;
  final ValueChanged<int>? onTap;
  final AppTabBarVariant variant;
  final double? tabHeight;
  final TabBarIndicatorSize indicatorSize;

  AppTabBarVariant _resolveVariant(BuildContext context) {
    if (variant != AppTabBarVariant.auto) {
      return variant;
    }
    final platform = Provider.of<AppPlatform?>(context, listen: false);
    return switch (platform) {
      AppPlatform.mobile => AppTabBarVariant.mobileTop,
      AppPlatform.desktop ||
      AppPlatform.web ||
      null =>
        AppTabBarVariant.desktop,
    };
  }

  _AppTabBarStyleSpec _spec(
    BuildContext context,
    AppTabBarVariant resolvedVariant,
  ) {
    final colors = context.appColors;
    final navigationTokens = context.appNavigationTokens;

    switch (resolvedVariant) {
      case AppTabBarVariant.auto:
        throw StateError('AppTabBarVariant.auto must be resolved before use.');
      case AppTabBarVariant.desktop:
        return _AppTabBarStyleSpec(
          visualTabHeight: navigationTokens.desktopTabHeight,
          labelPadding: EdgeInsets.only(
            right: navigationTokens.desktopTabLabelTrailingPadding,
          ),
          labelStyle: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.primary,
          ),
          unselectedLabelStyle: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: colors.divider,
          dividerHeight: 0.5,
          indicatorThickness: navigationTokens.desktopIndicatorThickness,
        );
      case AppTabBarVariant.compact:
        return _AppTabBarStyleSpec(
          visualTabHeight: navigationTokens.compactTabHeight,
          labelPadding: EdgeInsets.only(right: context.appSpacing.sm),
          labelStyle: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            tone: AppTextTone.primary,
          ),
          unselectedLabelStyle: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            tone: AppTextTone.muted,
          ),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          dividerHeight: 0,
          indicatorThickness: navigationTokens.compactIndicatorThickness,
        );
      case AppTabBarVariant.mobileTop:
        return _AppTabBarStyleSpec(
          dividerHeight: 0,
          visualTabHeight: navigationTokens.mobileTopTabHeight,
          labelPadding: EdgeInsets.only(right: context.appSpacing.sm),
          labelStyle: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            tone: AppTextTone.primary,
            weight: AppTextWeight.medium,
          ),
          unselectedLabelStyle: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            tone: AppTextTone.muted,
          ),
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          dividerColor: Colors.transparent,
          indicatorThickness: navigationTokens.compactIndicatorThickness,
        );
    }
  }

  Decoration _buildIndicator(BuildContext context, double thickness) {
    return _ThinTabIndicator(
      color: Theme.of(context).colorScheme.primary,
      thickness: thickness,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolvedVariant = _resolveVariant(context);
    final spec = _spec(context, resolvedVariant);
    final resolvedHeight = tabHeight ?? spec.visualTabHeight;
    final resolvedTabs = tabs
        .map((tab) => SizedBox(height: resolvedHeight, child: tab))
        .toList(growable: false);

    return TabBar(
      controller: controller,
      tabs: resolvedTabs,
      onTap: onTap,
      isScrollable: spec.isScrollable,
      tabAlignment: spec.tabAlignment,
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      labelPadding: spec.labelPadding,
      labelStyle: spec.labelStyle,
      unselectedLabelStyle: spec.unselectedLabelStyle,
      dividerColor: spec.dividerColor,
      dividerHeight: spec.dividerHeight,
      indicator: _buildIndicator(context, spec.indicatorThickness),
      indicatorSize: indicatorSize,
      indicatorPadding: EdgeInsets.zero,
    );
  }

  @override
  Size get preferredSize {
    final fallbackVariant =
        variant == AppTabBarVariant.auto ? AppTabBarVariant.desktop : variant;
    final resolvedHeight = tabHeight ?? _specFallbackHeight(fallbackVariant);
    return Size.fromHeight(resolvedHeight);
  }

  double _specFallbackHeight(AppTabBarVariant value) {
    switch (value) {
      case AppTabBarVariant.auto:
        throw StateError('AppTabBarVariant.auto must be resolved before use.');
      case AppTabBarVariant.desktop:
        return const AppNavigationTokens.defaults().desktopTabHeight;
      case AppTabBarVariant.compact:
        return const AppNavigationTokens.defaults().compactTabHeight;
      case AppTabBarVariant.mobileTop:
        return const AppNavigationTokens.mobile().mobileTopTabHeight;
    }
  }
}

class _ThinTabIndicator extends Decoration {
  const _ThinTabIndicator({required this.color, required this.thickness});

  final Color color;
  final double thickness;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _ThinTabIndicatorPainter(color: color, thickness: thickness);
  }
}

class _ThinTabIndicatorPainter extends BoxPainter {
  _ThinTabIndicatorPainter({required this.color, required this.thickness});

  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final y = offset.dy + size.height - (thickness / 2);
    final start = Offset(offset.dx + 2, y);
    final end = Offset(offset.dx + size.width - 2, y);
    canvas.drawLine(start, end, paint);
  }
}
