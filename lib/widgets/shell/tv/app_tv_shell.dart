import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/routes/app_route_target.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/decor/app_ambient_backdrop.dart';

class AppTvShell extends ConsumerWidget {
  const AppTvShell({
    super.key,
    required this.currentPath,
    required this.navItems,
    required this.child,
    this.showNav = true,
  });

  final String currentPath;
  final List<AppNavItem> navItems;
  final Widget child;
  final bool showNav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    return AppAmbientBackdrop(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showNav)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTvTokens.safeHorizontal,
                  vertical: AppTvTokens.safeVertical,
                ),
                child: SizedBox(
                  height: AppTvTokens.navHeight,
                  child: Row(
                    children: [
                      Text(
                        l10n.appTitle,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s32,
                          weight: AppTextWeight.semibold,
                          tone: AppTextTone.accent,
                        ),
                      ),
                      SizedBox(width: context.appSpacing.xxl),
                      Expanded(
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: navItems.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(width: context.appSpacing.sm),
                          itemBuilder: (context, index) {
                            final item = navItems[index];
                            final selected =
                                currentPath == item.path ||
                                currentPath.startsWith('${item.path}/');
                            return AppInteractiveSurface(
                              onTap: () =>
                                  AppRouteTarget(id: item.routeId).go(context),
                              focusRingRadius: context.appRadius.mdBorder,
                              child: _TvNavItem(item: item, selected: selected),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _TvNavItem extends StatelessWidget {
  const _TvNavItem({required this.item, required this.selected});

  final AppNavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AnimatedContainer(
      duration: context.appMotion.fast,
      constraints: const BoxConstraints(
        minWidth: AppTvTokens.navItemMinWidth,
        minHeight: AppTvTokens.navItemHeight,
      ),
      padding: EdgeInsets.symmetric(horizontal: context.appSpacing.lg),
      decoration: BoxDecoration(
        color: selected
            ? colors.surfaceElevated
            : colors.surfaceElevated.withValues(alpha: 0),
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? item.activeIcon ?? item.icon : item.icon,
            color: selected
                ? context.appTextPalette.primary
                : context.appTextPalette.secondary,
            size: context.appComponentTokens.iconSizeXl,
          ),
          SizedBox(width: context.appSpacing.sm),
          Text(
            item.label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s20,
              weight: selected ? AppTextWeight.semibold : AppTextWeight.medium,
              tone: selected ? AppTextTone.primary : AppTextTone.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
