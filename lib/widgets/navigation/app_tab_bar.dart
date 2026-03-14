import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

enum AppTabBarVariant { desktop, compact, mobileTop }

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
    this.variant = AppTabBarVariant.desktop,
    this.tabHeight,
    this.indicatorSize = TabBarIndicatorSize.label,
  });

  final List<Widget> tabs;
  final TabController? controller;
  final ValueChanged<int>? onTap;
  final AppTabBarVariant variant;
  final double? tabHeight;
  final TabBarIndicatorSize indicatorSize;

  _AppTabBarStyleSpec _spec(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    switch (variant) {
      case AppTabBarVariant.desktop:
        return _AppTabBarStyleSpec(
          visualTabHeight: 40,
          labelPadding: const EdgeInsets.only(right: 10),
          labelStyle: textTheme.titleSmall!.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
          unselectedLabelStyle: textTheme.titleSmall!.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: colors.divider,
          dividerHeight: 0.5,
          indicatorThickness: 3,
        );
      case AppTabBarVariant.compact:
        return _AppTabBarStyleSpec(
          visualTabHeight: 32,
          labelPadding: EdgeInsets.symmetric(horizontal: context.appSpacing.sm),
          labelStyle: textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
          unselectedLabelStyle: textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.w500,
            color: colors.textMuted,
          ),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          dividerHeight: 0,
          indicatorThickness: 3,
        );
      case AppTabBarVariant.mobileTop:
        return _AppTabBarStyleSpec(
          visualTabHeight: 48,
          labelPadding: EdgeInsets.symmetric(horizontal: context.appSpacing.lg),
          labelStyle: textTheme.titleSmall!.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
          unselectedLabelStyle: textTheme.titleSmall!.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: colors.textSecondary,
          ),
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          dividerColor: colors.divider,
          dividerHeight: 0.5,
          indicatorThickness: 5,
        );
    }
  }

  Decoration _buildIndicator(BuildContext context, double thickness) {
    return _ThinTabIndicator(
      color: Theme.of(context).colorScheme.primary,
      thickness: thickness,
    );
  }

  EdgeInsetsGeometry _indicatorPadding(double height, double thickness) {
    return EdgeInsets.only(
      top: (height - thickness).clamp(0.0, double.infinity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec(context);
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
      indicatorPadding: _indicatorPadding(
        resolvedHeight,
        spec.indicatorThickness,
      ),
    );
  }

  @override
  Size get preferredSize {
    final resolvedHeight = tabHeight ?? _specFallbackHeight(variant);
    return Size.fromHeight(resolvedHeight);
  }

  double _specFallbackHeight(AppTabBarVariant value) {
    switch (value) {
      case AppTabBarVariant.desktop:
        return 40;
      case AppTabBarVariant.compact:
        return 32;
      case AppTabBarVariant.mobileTop:
        return 48;
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

    final paint =
        Paint()
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
