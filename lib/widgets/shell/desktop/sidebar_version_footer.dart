import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/app_version_info_state.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/app/providers/app_update_check_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/configuration_tab_request_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/overlays/app_anchored_popover.dart';
import 'package:sakuramedia/widgets/shell/app_version_info_parts.dart';

const double _sidebarVersionUpdateDotSize = 6;

/// 桌面侧栏底部的版本信息：常态一行，点开后向上弹出轻量版本浮层。
///
/// 移动端抽屉继续使用 [AppVersionInfoCard]；更新检查状态两处共用
/// [appUpdateCheckProvider]（每小时轮询，失败静默），watch 即触发检查。
class SidebarVersionFooter extends ConsumerStatefulWidget {
  const SidebarVersionFooter({super.key = const Key('sidebar-version-info')});

  @override
  ConsumerState<SidebarVersionFooter> createState() =>
      _SidebarVersionFooterState();
}

class _SidebarVersionFooterState extends ConsumerState<SidebarVersionFooter> {
  static const double _popoverWidth = 300;

  final AppPopoverController _popoverController = AppPopoverController();

  void _openPlugins() {
    _popoverController.close();
    ref
        .read(configurationTabRequestProvider.notifier)
        .request('configuration-tab-plugins');
    context.goPrimaryRoute(desktopConfigurationPath);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(appShellSidebarCollapsedProvider, (previous, next) {
      if (next) {
        _popoverController.close();
      }
    });

    final versionInfo =
        ref.watch(appVersionInfoProvider).value ?? AppVersionInfoState.initial;
    final pluginUpdateCount =
        ref.watch(pluginsProvider).value?.updates.length ?? 0;
    final updates = ref.watch(appUpdateCheckProvider);
    final hasUpdates =
        updates.hasFrontendUpdate ||
        updates.hasBackendUpdate ||
        pluginUpdateCount > 0;
    final l10n = appL10n(context);
    final oneLine =
        '${versionInfo.frontendVersionLabel} · ${versionInfo.backendVersionLabel}';
    final tooltip = hasUpdates
        ? l10n.shellVersionTooltipUpdate(versionInfo.tooltipLabelFor(l10n))
        : versionInfo.tooltipLabelFor(l10n);

    return AppAnchoredPopover(
      controller: _popoverController,
      placement: AppPopoverPlacement.aboveStart,
      animate: true,
      focusOnOpen: true,
      panelWidthBuilder: (overlayContext, _, overlayWidth) =>
          math.min(_popoverWidth, overlayWidth - overlayContext.appSpacing.xxl),
      triggerBuilder: (context, _, toggle) => Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 300),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: context.appRadius.smBorder,
            mouseCursor: SystemMouseCursors.click,
            hoverColor: context.appColors.sidebarHoverBackground,
            onTap: toggle,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.appSpacing.sm,
                vertical: context.appSpacing.xs * 1.5,
              ),
              child: Row(
                children: [
                  _VersionInfoIcon(hasUpdates: hasUpdates),
                  SizedBox(width: context.appSpacing.sm),
                  Expanded(
                    child: Text(
                      oneLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s10,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      panelBuilder: (overlayContext, layout, _) => _VersionPopoverContent(
        width: layout.width,
        onGoPlugins: _openPlugins,
      ),
    );
  }
}

class _VersionInfoIcon extends StatelessWidget {
  const _VersionInfoIcon({required this.hasUpdates});

  final bool hasUpdates;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.info_outline_rounded,
      size: context.appComponentTokens.iconSizeSm,
      color: context.appTextPalette.muted,
    );
    if (!hasUpdates) {
      return icon;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -1,
          top: -1,
          child: Container(
            key: const Key('sidebar-version-update-dot'),
            width: _sidebarVersionUpdateDotSize,
            height: _sidebarVersionUpdateDotSize,
            decoration: BoxDecoration(
              color: context.appTextPalette.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

class _VersionPopoverContent extends ConsumerWidget {
  const _VersionPopoverContent({
    required this.width,
    required this.onGoPlugins,
  });

  final double width;
  final VoidCallback onGoPlugins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionInfo =
        ref.watch(appVersionInfoProvider).value ?? AppVersionInfoState.initial;
    final pluginUpdateCount =
        ref.watch(pluginsProvider).value?.updates.length ?? 0;
    final updates = ref.watch(appUpdateCheckProvider);
    final hasUpdates =
        updates.hasFrontendUpdate ||
        updates.hasBackendUpdate ||
        pluginUpdateCount > 0;
    final l10n = appL10n(context);
    final spacing = context.appSpacing;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: context.appRadius.lgBorder,
        boxShadow: context.appShadows.panel,
      ),
      child: Material(
        color: context.appColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: context.appRadius.lgBorder,
          side: BorderSide(color: context.appColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          key: const Key('sidebar-version-popover'),
          width: width,
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.shellSystemVersion,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.semibold,
                      ),
                    ),
                  ),
                  if (hasUpdates)
                    AppBadge(
                      label: l10n.shellUpdateBadge,
                      tone: AppBadgeTone.primary,
                      size: AppBadgeSize.compact,
                    ),
                ],
              ),
              SizedBox(height: spacing.md),
              AppVersionRow(
                label: l10n.shellClientLabel,
                value: versionInfo.frontendVersionLabel,
              ),
              SizedBox(height: spacing.xs),
              AppVersionRow(
                label: l10n.shellServerLabel,
                value: versionInfo.backendVersionLabel,
              ),
              if (hasUpdates) ...[
                SizedBox(height: spacing.sm),
                AppVersionUpdateNotice(
                  frontendUpdateVersion: updates.frontendUpdateVersion,
                  backendUpdateVersion: updates.backendUpdateVersion,
                  pluginUpdateCount: pluginUpdateCount,
                ),
              ],
              if (pluginUpdateCount > 0) ...[
                SizedBox(height: spacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: AppButton(
                    key: const Key('sidebar-version-popover-go-plugins'),
                    label: l10n.shellViewPluginUpdates,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.small,
                    onPressed: onGoPlugins,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
