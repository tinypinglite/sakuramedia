import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/format/app_number_format.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/shared/plugin_settings_content.dart';
import 'package:sakuramedia/features/plugins/presentation/plugin_management_actions.dart';
import 'package:sakuramedia/features/plugins/presentation/plugin_placeholders.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_dismiss_controller.dart';

/// 移动端插件管理页：卡片列表、操作抽屉、zip 安装和配置编辑。
class MobilePluginsPage extends ConsumerStatefulWidget {
  const MobilePluginsPage({super.key});

  @override
  ConsumerState<MobilePluginsPage> createState() => _MobilePluginsPageState();
}

class _MobilePluginsPageState extends ConsumerState<MobilePluginsPage> {
  PluginManagementActions get _actions =>
      PluginManagementActions(context: context, ref: ref);

  Future<void> _openSettings(PluginSummaryDto plugin) async {
    final dismissController = AppModalDismissController();
    await showAppBottomDrawer<void>(
      context: context,
      drawerKey: Key('mobile-plugin-settings-drawer-${plugin.pluginId}'),
      heightFactor: 0.9,
      dismissController: dismissController,
      builder: (_) => PluginSettingsContent(
        plugin: plugin,
        mobile: true,
        dismissController: dismissController,
      ),
    );
  }

  Future<void> _showActions(PluginSummaryDto plugin) async {
    final state = ref.read(pluginsProvider).value;
    final action = await _showMobilePluginActionsDrawer(
      context,
      plugin: plugin,
      update: state?.updates[plugin.pluginId],
      disabled:
          state == null ||
          state.isInstalling ||
          state.isCheckingUpdates ||
          state.busyPluginIds.contains(plugin.pluginId),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _MobilePluginAction.toggle:
        await _actions.toggle(plugin, !plugin.enabled);
      case _MobilePluginAction.update:
        final update = ref
            .read(pluginsProvider)
            .value
            ?.updates[plugin.pluginId];
        if (update != null) {
          await _actions.upgrade(plugin, update);
        }
      case _MobilePluginAction.delete:
        await _actions.remove(plugin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncPlugins = ref.watch(pluginsProvider);
    final state = asyncPlugins.value;
    final busy =
        state?.isInstalling == true ||
        state?.isCheckingUpdates == true ||
        state?.busyPluginIds.isNotEmpty == true;
    final colors = context.appColors;
    final spacing = context.appSpacing;

    return ColoredBox(
      key: const Key('mobile-settings-plugins'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: AppAdaptiveRefreshScrollView(
              onRefresh: _actions.refresh,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(top: spacing.sm, bottom: spacing.lg),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppNoticeCard(
                          key: const Key('mobile-plugins-restart-notice'),
                          leadingIcon: Icons.info_outline_rounded,
                          title: l10n.pluginsManagementTitle,
                          description: l10n.pluginsManageNotice,
                          stats: [
                            AppNoticeStat(
                              label: l10n.pluginsTabInstalled,
                              value: formatAppCount(state?.plugins.length ?? 0),
                              valueSize: AppTextSize.s18,
                            ),
                            AppNoticeStat(
                              label: l10n.pluginsUpdatableStat,
                              value: formatAppCount(state?.updates.length ?? 0),
                              valueSize: AppTextSize.s18,
                            ),
                          ],
                        ),
                        SizedBox(height: spacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                key: const Key(
                                  'mobile-plugins-check-updates-button',
                                ),
                                label: l10n.pluginsCheckUpdates,
                                icon: const Icon(Icons.system_update_outlined),
                                isLoading: state?.isCheckingUpdates == true,
                                onPressed:
                                    asyncPlugins.isLoading ||
                                        asyncPlugins.hasError ||
                                        busy
                                    ? null
                                    : _actions.checkUpdates,
                              ),
                            ),
                            SizedBox(width: spacing.sm),
                            Expanded(
                              child: Text(
                                state == null
                                    ? l10n.pluginsLoadingList
                                    : state.updates.isEmpty
                                    ? l10n.pluginsCheckReleaseUpdates
                                    : l10n.pluginsUpdatesFound(
                                        state.updates.length,
                                      ),
                                textAlign: TextAlign.end,
                                style: resolveAppTextStyle(
                                  context,
                                  size: AppTextSize.s12,
                                  tone: AppTextTone.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: spacing.md),
                        if ((asyncPlugins.isLoading && state == null) ||
                            (state != null && state.plugins.isNotEmpty))
                          AppSkeletonizer(
                            enabled: asyncPlugins.isLoading && state == null,
                            // loading 用占位插件渲染真实卡片列表，
                            // 由 [AppSkeletonizer] 灰化。
                            child: Builder(
                              builder: (context) {
                                final display =
                                    asyncPlugins.isLoading && state == null
                                    ? pluginsPlaceholderState()
                                    : state!;
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (
                                      var index = 0;
                                      index < display.plugins.length;
                                      index++
                                    ) ...[
                                      if (index > 0)
                                        SizedBox(height: spacing.sm),
                                      _MobilePluginCard(
                                        plugin: display.plugins[index],
                                        update:
                                            display.updates[display
                                                .plugins[index]
                                                .pluginId],
                                        busy: display.busyPluginIds.contains(
                                          display.plugins[index].pluginId,
                                        ),
                                        installing: display.isInstalling,
                                        checkingUpdates:
                                            display.isCheckingUpdates,
                                        onTap: () => _openSettings(
                                          display.plugins[index],
                                        ),
                                        onMore: () => _showActions(
                                          display.plugins[index],
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                          )
                        else if (asyncPlugins.hasError)
                          AppMobileSectionError(
                            key: const Key('mobile-plugins-error-state'),
                            title: l10n.pluginsLoadFailed,
                            message: apiErrorMessage(
                              asyncPlugins.error!,
                              fallback: l10n.pluginsLoadFailedFallback,
                              l10n: l10n,
                            ),
                            onRetry: _actions.refresh,
                            retryButtonKey: const Key(
                              'mobile-plugins-retry-button',
                            ),
                          )
                        else
                          const _MobilePluginsEmptyState(
                            key: Key('mobile-plugins-empty-state'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: spacing.sm, bottom: spacing.md),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    key: const Key('mobile-plugins-market-button'),
                    label: l10n.pluginsMarket,
                    variant: AppButtonVariant.secondary,
                    icon: const Icon(Icons.storefront_outlined),
                    onPressed: () =>
                        MobileRoutes.settingsPluginMarket().push(context),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: AppButton(
                    key: const Key('mobile-plugins-install-button'),
                    label: l10n.pluginInstallTitle,
                    variant: AppButtonVariant.primary,
                    icon: const Icon(Icons.upload_file_outlined),
                    isLoading: state?.isInstalling == true,
                    onPressed:
                        asyncPlugins.isLoading || asyncPlugins.hasError || busy
                        ? null
                        : _actions.install,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobilePluginsEmptyState extends StatelessWidget {
  const _MobilePluginsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppContentCard(
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.xl,
      ),
      child: AppEmptyState(
        icon: Icons.extension_outlined,
        title: l10n.pluginsEmptyTitle,
        message: l10n.pluginsEmptyMessageMobile,
      ),
    );
  }
}

class _MobilePluginCard extends StatelessWidget {
  const _MobilePluginCard({
    required this.plugin,
    required this.update,
    required this.busy,
    required this.installing,
    required this.checkingUpdates,
    required this.onTap,
    required this.onMore,
  });

  final PluginSummaryDto plugin;
  final PluginReleaseUpdate? update;
  final bool busy;
  final bool installing;
  final bool checkingUpdates;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final disabled = busy || installing || checkingUpdates;
    return AppContentCard(
      key: Key('mobile-plugin-card-${plugin.pluginId}'),
      padding: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: AppInteractiveSurface(
                enabled: !disabled,
                key: Key('mobile-plugin-card-body-${plugin.pluginId}'),
                onTap: disabled ? null : onTap,
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width:
                            context.appComponentTokens.iconSizeXl + spacing.md,
                        height:
                            context.appComponentTokens.iconSizeXl + spacing.md,
                        decoration: BoxDecoration(
                          color: context.appColors.surfaceMuted,
                          borderRadius: context.appRadius.mdBorder,
                        ),
                        child: Icon(
                          Icons.extension_outlined,
                          color: context.appTextPalette.secondary,
                          size: context.appComponentTokens.iconSizeMd,
                        ),
                      ),
                      SizedBox(width: spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: spacing.xs,
                              runSpacing: spacing.xs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  plugin.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: resolveAppTextStyle(
                                    context,
                                    size: AppTextSize.s14,
                                    weight: AppTextWeight.medium,
                                    tone: AppTextTone.primary,
                                  ),
                                ),
                                AppStatusChip(
                                  label: plugin.enabled
                                      ? l10n.pluginsEnabled
                                      : l10n.pluginsDisabled,
                                  palette: AppStatusChipPalette.forSemantic(
                                    plugin.enabled
                                        ? AppStatusSemantic.success
                                        : AppStatusSemantic.neutral,
                                  ),
                                  dense: true,
                                ),
                                if (plugin.loadStatus == 'error')
                                  Tooltip(
                                    message:
                                        plugin.loadError ??
                                        l10n.pluginsLoadErrorTooltip,
                                    child: AppStatusChip(
                                      label: l10n.pluginsLoadErrorBadge,
                                      palette: AppStatusChipPalette.forSemantic(
                                        AppStatusSemantic.error,
                                      ),
                                      dense: true,
                                    ),
                                  ),
                                if (update != null)
                                  AppStatusChip(
                                    label: l10n.pluginsUpdateAvailable,
                                    palette: AppStatusChipPalette.forSemantic(
                                      AppStatusSemantic.warning,
                                    ),
                                    dense: true,
                                  ),
                              ],
                            ),
                            SizedBox(height: spacing.xs),
                            Text(
                              'v${plugin.version} · ${plugin.pluginId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: resolveAppTextStyle(
                                context,
                                size: AppTextSize.s12,
                                tone: AppTextTone.secondary,
                              ),
                            ),
                            if (plugin.loadStatus == 'error' &&
                                plugin.loadError != null &&
                                plugin.loadError!.trim().isNotEmpty) ...[
                              SizedBox(height: spacing.xs),
                              Text(
                                plugin.loadError!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: resolveAppTextStyle(
                                  context,
                                  size: AppTextSize.s12,
                                  tone: AppTextTone.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: spacing.sm, right: spacing.sm),
            child: AppIconButton(
              key: Key('mobile-plugin-more-${plugin.pluginId}'),
              tooltip: l10n.pluginsMoreActions,
              semanticLabel: l10n.pluginsManageSemantic(plugin.displayName),
              icon: const Icon(Icons.more_horiz_rounded),
              onPressed: disabled ? null : onMore,
            ),
          ),
        ],
      ),
    );
  }
}

enum _MobilePluginAction { toggle, update, delete }

Future<_MobilePluginAction?> _showMobilePluginActionsDrawer(
  BuildContext context, {
  required PluginSummaryDto plugin,
  required PluginReleaseUpdate? update,
  required bool disabled,
}) {
  return showAppBottomDrawer<_MobilePluginAction>(
    context: context,
    drawerKey: Key('mobile-plugin-actions-drawer-${plugin.pluginId}'),
    maxHeightFactor: 0.58,
    builder: (_) => _MobilePluginActionsSheet(
      plugin: plugin,
      update: update,
      disabled: disabled,
    ),
  );
}

class _MobilePluginActionsSheet extends StatelessWidget {
  const _MobilePluginActionsSheet({
    required this.plugin,
    required this.update,
    required this.disabled,
  });

  final PluginSummaryDto plugin;
  final PluginReleaseUpdate? update;
  final bool disabled;

  void _select(BuildContext context, _MobilePluginAction action) {
    if (disabled) {
      return;
    }
    Navigator.of(context).pop(action);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            plugin.displayName,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            l10n.pluginsActionsTitle,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.md),
          _MobilePluginActionRow(
            key: Key('mobile-plugin-toggle-${plugin.pluginId}'),
            icon: plugin.enabled
                ? Icons.pause_circle_outline_rounded
                : Icons.play_circle_outline_rounded,
            label: plugin.enabled ? l10n.pluginsDisable : l10n.pluginsEnable,
            disabled: disabled,
            onTap: () => _select(context, _MobilePluginAction.toggle),
          ),
          if (update != null)
            _MobilePluginActionRow(
              key: Key('mobile-plugin-update-${plugin.pluginId}'),
              icon: Icons.system_update_outlined,
              label: l10n.pluginsUpdateTo(update!.version),
              disabled: disabled,
              onTap: () => _select(context, _MobilePluginAction.update),
            ),
          _MobilePluginActionRow(
            key: Key('mobile-plugin-delete-${plugin.pluginId}'),
            icon: Icons.delete_outline_rounded,
            label: l10n.pluginDeleteTitle,
            danger: true,
            disabled: disabled,
            onTap: () => _select(context, _MobilePluginAction.delete),
          ),
        ],
      ),
    );
  }
}

class _MobilePluginActionRow extends StatelessWidget {
  const _MobilePluginActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.disabled,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool disabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final foreground = danger
        ? context.appTextPalette.error
        : context.appTextPalette.primary;
    return Opacity(
      opacity: disabled ? 0.56 : 1,
      child: Material(
        color: Colors.transparent,
        child: AppInteractiveSurface(
          enabled: !disabled,
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.md),
            child: Row(
              children: [
                Icon(icon, color: foreground),
                SizedBox(width: spacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      tone: danger ? AppTextTone.error : AppTextTone.primary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.appTextPalette.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
