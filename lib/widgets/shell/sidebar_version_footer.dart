import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_version_info_state.dart';
import 'package:sakuramedia/app/providers/app_update_check_provider.dart'
    show AppUpdateCheckState;
import 'package:sakuramedia/features/announcements/data/announcement_dto.dart';
import 'package:sakuramedia/features/announcements/presentation/widgets/announcement_level_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_anchored_menu.dart';

/// 账户卡里的版本入口：常态一行，点开后显示版本和可用更新。
///
/// 只负责展示和局部菜单交互；版本、更新状态与外链打开由容器提供。
class SidebarVersionFooter extends StatelessWidget {
  const SidebarVersionFooter({
    super.key = const Key('sidebar-version-info'),
    required this.version,
    required this.pluginUpdates,
    required this.updates,
    required this.onOpenFrontendRelease,
    required this.onOpenBackendRelease,
    required this.onOpenPluginUpdates,
    this.announcements = const <AnnouncementDto>[],
    this.hasUnseenAnnouncements = false,
    this.onOpenAnnouncement,
    this.onMenuOpened,
    this.onMenuClosed,
  });

  final AppVersionInfoState version;
  final int pluginUpdates;
  final AppUpdateCheckState updates;
  final VoidCallback onOpenFrontendRelease;
  final VoidCallback onOpenBackendRelease;
  final VoidCallback onOpenPluginUpdates;
  final List<AnnouncementDto> announcements;
  final bool hasUnseenAnnouncements;
  final ValueChanged<AnnouncementDto>? onOpenAnnouncement;
  final VoidCallback? onMenuOpened;
  final VoidCallback? onMenuClosed;

  @override
  Widget build(BuildContext context) {
    final hasUpdates =
        updates.hasFrontendUpdate ||
        updates.hasBackendUpdate ||
        pluginUpdates > 0;
    final l10n = appL10n(context);
    final tooltip = hasUnseenAnnouncements
        ? l10n.shellVersionTooltipNotice(version.tooltipLabelFor(l10n))
        : hasUpdates
        ? l10n.shellVersionTooltipUpdate(version.tooltipLabelFor(l10n))
        : version.tooltipLabelFor(l10n);

    return AppGlassAnchoredMenu(
      width: 300,
      minWidth: 300,
      maxWidth: 300,
      estimatedHeight: 360,
      maxHeight: 420,
      borderRadius: context.appRadius.lgBorder,
      panelKey: const Key('sidebar-version-popover'),
      onOpen: onMenuOpened,
      onClose: onMenuClosed,
      triggerBuilder: (context, isOpen, toggle) => Tooltip(
        message: tooltip,
        child: Semantics(
          label: tooltip,
          child: AppInteractiveSurface(
            onTap: toggle,
            focusRingRadius: context.appRadius.smBorder,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.appSpacing.sm,
                vertical: context.appSpacing.xs * 1.5,
              ),
              child: Row(
                children: <Widget>[
                  _VersionInfoIcon(
                    hasUpdates: hasUpdates,
                    hasUnseenAnnouncements: hasUnseenAnnouncements,
                  ),
                  SizedBox(width: context.appSpacing.sm),
                  Expanded(
                    child: Text(
                      '${version.frontendVersionLabel} · '
                      '${version.backendVersionLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s10,
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
      contentBuilder: (context, close) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.appSpacing.md,
              context.appSpacing.sm,
              context.appSpacing.md,
              context.appSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
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
          ),
          _versionRow(
            context,
            l10n.shellClientLabel,
            version.frontendVersionLabel,
          ),
          _versionRow(
            context,
            l10n.shellServerLabel,
            version.backendVersionLabel,
          ),
          if (hasUpdates)
            Padding(
              key: const Key('sidebar-update-notice'),
              padding: EdgeInsets.symmetric(
                horizontal: context.appSpacing.md,
                vertical: context.appSpacing.sm,
              ),
              child: _UpdateSummary(
                frontendUpdateVersion: updates.frontendUpdateVersion,
                backendUpdateVersion: updates.backendUpdateVersion,
                pluginUpdates: pluginUpdates,
              ),
            ),
          if (updates.hasFrontendUpdate)
            _action(
              context,
              key: const Key('version-release-link-frontend'),
              label: l10n.shellClientReleasePage,
              onTap: () {
                close();
                onOpenFrontendRelease();
              },
            ),
          if (updates.hasBackendUpdate)
            _action(
              context,
              key: const Key('version-release-link-backend'),
              label: l10n.shellServerReleasePage,
              onTap: () {
                close();
                onOpenBackendRelease();
              },
            ),
          if (pluginUpdates > 0)
            _action(
              context,
              key: const Key('sidebar-version-popover-go-plugins'),
              label: l10n.shellViewPluginUpdates,
              onTap: () {
                close();
                onOpenPluginUpdates();
              },
              primary: true,
            ),
          if (announcements.isNotEmpty)
            _announcementSection(context, close: close, l10n: l10n),
        ],
      ),
    );
  }

  Widget _announcementSection(
    BuildContext context, {
    required VoidCallback close,
    required AppLocalizations l10n,
  }) {
    final locale = Localizations.localeOf(context);
    return Padding(
      key: const Key('sidebar-announcements-section'),
      padding: EdgeInsets.only(top: context.appSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.appSpacing.md,
              context.appSpacing.xs,
              context.appSpacing.md,
              context.appSpacing.xs,
            ),
            child: Text(
              l10n.shellAnnouncementsTitle,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.secondary,
              ),
            ),
          ),
          for (final announcement in announcements)
            AppGlassMenuRow(
              key: Key('sidebar-announcement-${announcement.id}'),
              leading: Icon(
                announcement.level.icon,
                size: context.appComponentTokens.iconSizeSm,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(announcement.titleFor(locale)),
              subtitle: Text(announcement.bodyFor(locale)),
              trailing: AppBadge(
                label: announcement.level.label(l10n),
                tone: announcement.level.badgeTone,
                size: AppBadgeSize.compact,
              ),
              minHeight: 52,
              onTap: onOpenAnnouncement == null
                  ? null
                  : () {
                      close();
                      onOpenAnnouncement!(announcement);
                    },
            ),
        ],
      ),
    );
  }
}

Widget _versionRow(BuildContext context, String label, String value) {
  return AppGlassMenuRow(
    title: Text(label),
    titleStyle: resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      tone: AppTextTone.muted,
    ),
    trailing: Text(
      value,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.medium,
        tone: AppTextTone.tertiary,
      ),
    ),
    enabled: false,
    minHeight: 32,
  );
}

Widget _action(
  BuildContext context, {
  required Key key,
  required String label,
  required VoidCallback onTap,
  bool primary = false,
}) {
  return AppGlassMenuRow(
    key: key,
    title: Text(label),
    titleStyle: resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: primary ? AppTextWeight.medium : AppTextWeight.regular,
      tone: primary ? AppTextTone.accent : AppTextTone.primary,
    ),
    minHeight: 36,
    onTap: onTap,
  );
}

class _VersionInfoIcon extends StatelessWidget {
  const _VersionInfoIcon({
    required this.hasUpdates,
    required this.hasUnseenAnnouncements,
  });

  final bool hasUpdates;
  final bool hasUnseenAnnouncements;

  @override
  Widget build(BuildContext context) {
    return Badge(
      key: const Key('sidebar-version-update-dot'),
      isLabelVisible: hasUpdates || hasUnseenAnnouncements,
      smallSize: 6,
      backgroundColor: hasUnseenAnnouncements
          ? context.appTextPalette.error
          : context.appTextPalette.accent,
      child: Icon(
        Icons.info_outline_rounded,
        size: context.appComponentTokens.iconSizeSm,
        color: context.appTextPalette.muted,
      ),
    );
  }
}

class _UpdateSummary extends StatelessWidget {
  const _UpdateSummary({
    required this.frontendUpdateVersion,
    required this.backendUpdateVersion,
    required this.pluginUpdates,
  });

  final String? frontendUpdateVersion;
  final String? backendUpdateVersion;
  final int pluginUpdates;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final details = <String>[
      if (frontendUpdateVersion != null)
        l10n.shellClientVersion(frontendUpdateVersion!),
      if (backendUpdateVersion != null)
        l10n.shellServerVersion(backendUpdateVersion!),
      if (pluginUpdates > 0) l10n.shellPluginUpdateCount(pluginUpdates),
    ].join(' · ');

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: l10n.shellUpdatesAvailable,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.medium,
              tone: AppTextTone.accent,
            ),
          ),
          TextSpan(
            text: '\n$details',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              tone: AppTextTone.accent,
            ),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
