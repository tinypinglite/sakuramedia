import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/shell/sidebar_appearance_menu.dart';
import 'package:sakuramedia/widgets/shell/sidebar_version_footer.dart';

/// 侧栏底部账户卡：产品信息、外观入口、版本信息和退出登录。
///
/// 桌面侧栏与移动概览抽屉共用，避免两端各维护一套底部操作区。
class AppSidebarAccountCard extends StatelessWidget {
  const AppSidebarAccountCard({
    super.key = const Key('sidebar-account-card'),
    required this.onLogout,
    required this.onOpenPluginUpdates,
    this.logoutKey = const Key('sidebar-logout-button'),
  });

  final VoidCallback onLogout;
  final VoidCallback onOpenPluginUpdates;
  final Key logoutKey;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonFill = colors.surfaceCard.withValues(
      alpha: isDark ? 0.06 : 0.34,
    );
    final buttonBorder = colors.borderSubtle.fadedBy(isDark ? 0.75 : 0.55);
    final cardFill = colors.surfaceCard.withValues(
      alpha: isDark ? 0.055 : 0.34,
    );

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 88),
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: cardFill,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(
          color: colors.borderSubtle.fadedBy(isDark ? 0.72 : 0.50),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                key: const Key('sidebar-account-avatar'),
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Text(
                  'S',
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.medium,
                  ).copyWith(color: Theme.of(context).colorScheme.onPrimary),
                ),
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.appTitle,
                      key: const Key('sidebar-account-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: AppTextWeight.medium,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: context.appTextPalette.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: spacing.xs),
                        Flexible(
                          child: Text(
                            l10n.shellSignedIn,
                            key: const Key('sidebar-account-status'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: resolveAppTextStyle(
                              context,
                              size: AppTextSize.s10,
                              tone: AppTextTone.tertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.xs),
              const SidebarAppearanceMenu(),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: SidebarVersionFooter(
                  onOpenPluginUpdates: onOpenPluginUpdates,
                ),
              ),
              SizedBox(width: spacing.xs),
              AppIconButton(
                key: logoutKey,
                icon: const Icon(Icons.logout_rounded),
                tooltip: l10n.shellLogout,
                semanticLabel: l10n.shellLogout,
                iconColor: context.appTextPalette.tertiary,
                backgroundColor: buttonFill,
                borderColor: buttonBorder,
                borderRadius: context.appRadius.smBorder,
                onPressed: onLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
