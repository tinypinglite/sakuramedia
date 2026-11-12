import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/desktop/plugin_market_section.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/desktop/plugin_settings_dialog.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/shared/plugin_test_dialog.dart';
import 'package:sakuramedia/features/plugins/presentation/plugin_management_actions.dart';
import 'package:sakuramedia/features/plugins/presentation/plugin_placeholders.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_switch.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 系统设置里的「插件」页：分「已安装」「插件市场」两个分栏。
class DesktopPluginsSection extends ConsumerStatefulWidget {
  const DesktopPluginsSection({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<DesktopPluginsSection> createState() =>
      _DesktopPluginsSectionState();
}

class _DesktopPluginsSectionState extends ConsumerState<DesktopPluginsSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  PluginManagementActions get _actions =>
      PluginManagementActions(context: context, ref: ref);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openSettings(PluginSummaryDto plugin) {
    unawaited(showPluginSettingsDialog(context, plugin: plugin));
  }

  void _openTest(PluginSummaryDto plugin) {
    unawaited(showPluginTestDialog(context, plugin: plugin));
  }

  Future<void> _onRefresh() {
    if (_tabController.index == 1) {
      return _actions.refreshMarket();
    }
    return _actions.refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return const SizedBox.shrink();
    }
    final asyncPlugins = ref.watch(pluginsProvider);
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return AppPageRefreshScope(
      onRefresh: _onRefresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTabBar(
            key: const Key('plugins-tab-bar'),
            controller: _tabController,
            onTap: (_) => setState(() {}),
            tabs: [
              Tab(text: l10n.pluginsTabInstalled),
              Tab(text: l10n.pluginsTabMarket),
            ],
          ),
          SizedBox(height: spacing.lg),
          if (_tabController.index == 0)
            _buildInstalled(context, asyncPlugins)
          else
            const DesktopPluginMarketSection(),
        ],
      ),
    );
  }

  Widget _buildInstalled(
    BuildContext context,
    AsyncValue<PluginsState> asyncPlugins,
  ) {
    final l10n = AppLocalizations.of(context);
    if (asyncPlugins.hasError) {
      return AppSectionError(
        title: l10n.pluginsLoadFailed,
        message: apiErrorMessage(
          asyncPlugins.error!,
          fallback: l10n.pluginsLoadFailedFallback,
          l10n: l10n,
        ),
        onRetry: _actions.refresh,
      );
    }
    final isLoading = asyncPlugins.value == null;
    // loading 用占位插件渲染真实列表行，由 [AppSkeletonizer] 灰化。
    final state = isLoading ? pluginsPlaceholderState() : asyncPlugins.value!;
    return AppSkeletonizer(
      enabled: isLoading,
      child: _buildLoaded(context, state),
    );
  }

  Widget _buildLoaded(BuildContext context, PluginsState state) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < state.plugins.length; i++) {
      final plugin = state.plugins[i];
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            indent: spacing.xl,
            color: context.appColors.borderSubtle,
          ),
        );
      }
      rows.add(
        _PluginRow(
          plugin: plugin,
          update: state.updates[plugin.pluginId],
          busy: state.busyPluginIds.contains(plugin.pluginId),
          installing: state.isInstalling,
          checkingUpdates: state.isCheckingUpdates,
          onTap: () => _openSettings(plugin),
          onTest:
              plugin.enabled &&
                  plugin.loadStatus == 'ok' &&
                  plugin.testCapabilities.isNotEmpty
              ? () => _openTest(plugin)
              : null,
          onToggle: (enabled) => _actions.toggle(plugin, enabled),
          onUpgrade: (update) => _actions.upgrade(plugin, update),
          onRemove: () => _actions.remove(plugin),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppNoticeCard(
          key: const Key('plugins-restart-notice'),
          leadingIcon: Icons.info_outline_rounded,
          description: l10n.pluginsRestartNotice,
        ),
        SizedBox(height: spacing.lg),
        Row(
          children: [
            AppButton(
              key: const Key('plugins-check-updates-button'),
              label: l10n.pluginsCheckUpdates,
              size: AppButtonSize.small,
              icon: const Icon(Icons.system_update_outlined),
              isLoading: state.isCheckingUpdates,
              onPressed:
                  state.isInstalling ||
                      state.isCheckingUpdates ||
                      state.busyPluginIds.isNotEmpty
                  ? null
                  : _actions.checkUpdates,
            ),
            SizedBox(width: spacing.sm),
            // 主行动保留品牌底色会显得「加载中也可用」，用 shade 随骨架一起灰化。
            Skeleton.shade(
              child: AppButton(
                key: const Key('plugins-install-button'),
                label: l10n.pluginInstallTitle,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.small,
                icon: const Icon(Icons.upload_file_outlined),
                isLoading: state.isInstalling,
                onPressed: state.isInstalling || state.busyPluginIds.isNotEmpty
                    ? null
                    : _actions.install,
              ),
            ),
            SizedBox(width: spacing.md),
            Text(
              l10n.pluginsZipSupport,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.muted,
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.lg),
        if (state.plugins.isEmpty)
          AppEmptyState(
            key: const Key('plugins-empty-state'),
            icon: Icons.extension_outlined,
            title: l10n.pluginsEmptyTitle,
            message: l10n.pluginsEmptyMessage,
          )
        else
          AppContentCard(
            key: const Key('plugins-list-card'),
            title: l10n.pluginsInstalledTitle,
            headerTrailing: AppBadge(
              label: l10n.pluginsCount(state.plugins.length),
              tone: AppBadgeTone.neutral,
            ),
            padding: EdgeInsets.all(spacing.lg),
            headerBottomSpacing: spacing.sm,
            child: Column(children: rows),
          ),
      ],
    );
  }
}

class _PluginRow extends StatelessWidget {
  const _PluginRow({
    required this.plugin,
    required this.update,
    required this.busy,
    required this.installing,
    required this.checkingUpdates,
    required this.onTap,
    required this.onTest,
    required this.onToggle,
    required this.onUpgrade,
    required this.onRemove,
  });

  final PluginSummaryDto plugin;
  final PluginReleaseUpdate? update;
  final bool busy;
  final bool installing;
  final bool checkingUpdates;
  final VoidCallback onTap;
  final VoidCallback? onTest;
  final ValueChanged<bool> onToggle;
  final ValueChanged<PluginReleaseUpdate> onUpgrade;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final disabled = busy || installing || checkingUpdates;
    return AppInteractiveSurface(
      enabled: !disabled,
      key: Key('plugin-row-${plugin.pluginId}'),
      onTap: disabled ? null : onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.md),
        child: Row(
          children: [
            Icon(
              Icons.extension_outlined,
              size: context.appComponentTokens.iconSizeMd,
              color: context.appTextPalette.muted,
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
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
                      ),
                      if (plugin.loadStatus == 'error') ...[
                        SizedBox(width: spacing.sm),
                        Tooltip(
                          message:
                              plugin.loadError ?? l10n.pluginsLoadErrorTooltip,
                          child: AppStatusChip(
                            label: l10n.pluginsLoadErrorBadge,
                            palette: AppStatusChipPalette.forSemantic(
                              AppStatusSemantic.error,
                            ),
                            dense: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: spacing.xs / 2),
                  Text(
                    'v${plugin.version} · ${plugin.pluginId}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: spacing.md),
            if (update != null) ...[
              AppButton(
                key: Key('plugin-upgrade-button-${plugin.pluginId}'),
                label: l10n.pluginsUpdateAction,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.xSmall,
                onPressed: disabled ? null : () => onUpgrade(update!),
              ),
              SizedBox(width: spacing.xs),
            ],
            if (busy)
              const AppInlineSpinner()
            else
              AppSwitch(
                key: Key('plugin-enabled-switch-${plugin.pluginId}'),
                value: plugin.enabled,
                onChanged: disabled ? null : onToggle,
              ),
            SizedBox(width: spacing.xs),
            if (onTest != null)
              AppIconButton(
                key: Key('plugin-test-button-${plugin.pluginId}'),
                tooltip: l10n.pluginsTestCapabilities,
                semanticLabel: l10n.pluginsTestCapabilities,
                icon: const Icon(Icons.science_outlined),
                onPressed: disabled ? null : onTest,
              ),
            if (onTest != null) SizedBox(width: spacing.xs),
            AppIconButton(
              key: Key('plugin-remove-button-${plugin.pluginId}'),
              tooltip: l10n.pluginDeleteTitle,
              semanticLabel: l10n.pluginsDeleteSemantic(plugin.displayName),
              icon: const Icon(Icons.delete_outline_rounded),
              iconColor: context.appTextPalette.error,
              onPressed: disabled ? null : onRemove,
            ),
            SizedBox(width: spacing.xs),
            Icon(
              Icons.chevron_right_rounded,
              size: context.appComponentTokens.iconSizeSm,
              color: context.appTextPalette.muted,
            ),
          ],
        ),
      ),
    );
  }
}
