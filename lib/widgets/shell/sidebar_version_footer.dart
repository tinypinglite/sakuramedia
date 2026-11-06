import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/app_version_info_state.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/app/providers/app_update_check_provider.dart';
import 'package:sakuramedia/app/providers/external_url_provider.dart';
import 'package:sakuramedia/config/app_release_channels.dart';
import 'package:sakuramedia/core/platform/clipboard_copy.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';

enum _VersionAction { frontendRelease, backendRelease, plugins }

/// 账户卡里的版本入口：常态一行，点开后显示版本和可用更新。
class SidebarVersionFooter extends ConsumerStatefulWidget {
  const SidebarVersionFooter({
    super.key = const Key('sidebar-version-info'),
    required this.onOpenPluginUpdates,
  });

  final VoidCallback onOpenPluginUpdates;

  @override
  ConsumerState<SidebarVersionFooter> createState() =>
      _SidebarVersionFooterState();
}

class _SidebarVersionFooterState extends ConsumerState<SidebarVersionFooter> {
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(appShellSidebarCollapsedProvider, (_, next) {
      if (next && _menuOpen) {
        _menuOpen = false;
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    });

    final version =
        ref.watch(appVersionInfoProvider).value ?? AppVersionInfoState.initial;
    final pluginUpdates = ref.watch(pluginsProvider).value?.updates.length ?? 0;
    final updates = ref.watch(appUpdateCheckProvider);
    final hasUpdates =
        updates.hasFrontendUpdate ||
        updates.hasBackendUpdate ||
        pluginUpdates > 0;
    final l10n = appL10n(context);
    final tooltip = hasUpdates
        ? l10n.shellVersionTooltipUpdate(version.tooltipLabelFor(l10n))
        : version.tooltipLabelFor(l10n);

    return PopupMenuButton<_VersionAction>(
      tooltip: tooltip,
      color: context.appColors.surfaceCard,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      constraints: const BoxConstraints.tightFor(width: 300),
      shape: RoundedRectangleBorder(
        borderRadius: context.appRadius.lgBorder,
        side: BorderSide(color: context.appColors.borderSubtle),
      ),
      onOpened: () => _menuOpen = true,
      onCanceled: () => _menuOpen = false,
      onSelected: (action) {
        _menuOpen = false;
        switch (action) {
          case _VersionAction.frontendRelease:
            unawaited(
              _openRelease(context, ref, AppReleaseChannels.frontendPageUrl),
            );
          case _VersionAction.backendRelease:
            unawaited(
              _openRelease(context, ref, AppReleaseChannels.backendPageUrl),
            );
          case _VersionAction.plugins:
            widget.onOpenPluginUpdates();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          key: const Key('sidebar-version-popover'),
          enabled: false,
          height: 44,
          child: Row(
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
          PopupMenuItem(
            key: const Key('sidebar-update-notice'),
            enabled: false,
            height: 76,
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
            value: _VersionAction.frontendRelease,
          ),
        if (updates.hasBackendUpdate)
          _action(
            context,
            key: const Key('version-release-link-backend'),
            label: l10n.shellServerReleasePage,
            value: _VersionAction.backendRelease,
          ),
        if (pluginUpdates > 0)
          _action(
            context,
            key: const Key('sidebar-version-popover-go-plugins'),
            label: l10n.shellViewPluginUpdates,
            value: _VersionAction.plugins,
            primary: true,
          ),
      ],
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
                '${version.frontendVersionLabel} · ${version.backendVersionLabel}',
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
    );
  }
}

PopupMenuItem<_VersionAction> _versionRow(
  BuildContext context,
  String label,
  String value,
) {
  return PopupMenuItem<_VersionAction>(
    enabled: false,
    height: 32,
    child: Row(
      children: [
        Text(
          label,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: AppTextTone.tertiary,
          ),
        ),
      ],
    ),
  );
}

PopupMenuItem<_VersionAction> _action(
  BuildContext context, {
  required Key key,
  required String label,
  required _VersionAction value,
  bool primary = false,
}) {
  return PopupMenuItem<_VersionAction>(
    key: key,
    value: value,
    height: 36,
    child: Text(
      label,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: primary ? AppTextWeight.medium : AppTextWeight.regular,
        tone: primary ? AppTextTone.accent : AppTextTone.primary,
      ),
    ),
  );
}

class _VersionInfoIcon extends StatelessWidget {
  const _VersionInfoIcon({required this.hasUpdates});

  final bool hasUpdates;

  @override
  Widget build(BuildContext context) {
    return Badge(
      key: const Key('sidebar-version-update-dot'),
      isLabelVisible: hasUpdates,
      smallSize: 6,
      backgroundColor: context.appTextPalette.accent,
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

Future<void> _openRelease(
  BuildContext context,
  WidgetRef ref,
  String url,
) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return;
  }
  final l10n = appL10n(context);
  final opened = await ref.read(externalUrlOpenerProvider)(uri);
  if (opened || !context.mounted) {
    return;
  }
  final copied = await copyTextToClipboard(url);
  if (!context.mounted) {
    return;
  }
  showToast(
    copied ? l10n.shellBrowserOpenFailedCopied : l10n.shellBrowserOpenFailed,
    tone: AppToastTone.error,
  );
}
