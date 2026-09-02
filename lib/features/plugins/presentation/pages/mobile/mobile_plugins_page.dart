import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/shared/plugin_settings_content.dart';
import 'package:sakuramedia/features/plugins/presentation/plugin_management_actions.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';

/// 移动端插件管理页：卡片列表、操作抽屉、zip 安装和配置编辑。
class MobilePluginsPage extends ConsumerStatefulWidget {
  const MobilePluginsPage({super.key});

  @override
  ConsumerState<MobilePluginsPage> createState() => _MobilePluginsPageState();
}

class _MobilePluginsPageState extends ConsumerState<MobilePluginsPage> {
  PluginManagementActions get _actions =>
      PluginManagementActions(context: context, ref: ref);

  Future<void> _openSettings(PluginSummaryDto plugin) {
    return showAppBottomDrawer<void>(
      context: context,
      drawerKey: Key('mobile-plugin-settings-drawer-${plugin.pluginId}'),
      heightFactor: 0.9,
      builder: (_) => PluginSettingsContent(plugin: plugin, mobile: true),
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
      color: colors.surfacePage,
      child: Column(
        children: [
          Expanded(
            child: AppAdaptiveRefreshScrollView(
              onRefresh: _actions.refresh,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    spacing.md,
                    spacing.sm,
                    spacing.md,
                    spacing.lg,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppNoticeCard(
                          key: const Key('mobile-plugins-restart-notice'),
                          leadingIcon: Icons.info_outline_rounded,
                          title: '插件管理',
                          description: '安装、更新、启停、删除或配置修改后，需重启容器才会生效。',
                          stats: [
                            AppNoticeStat(
                              label: '已安装',
                              value: '${state?.plugins.length ?? 0}',
                              valueSize: AppTextSize.s18,
                            ),
                            AppNoticeStat(
                              label: '可更新',
                              value: '${state?.updates.length ?? 0}',
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
                                label: '检查更新',
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
                                    ? '正在加载插件列表'
                                    : state.updates.isEmpty
                                    ? '检查插件 Release 更新'
                                    : '发现 ${state.updates.length} 个更新',
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
                        if (asyncPlugins.isLoading && state == null)
                          const AppMobileSkeletonList(
                            key: Key('mobile-plugins-loading-state'),
                            itemCount: 3,
                            padding: EdgeInsets.zero,
                          )
                        else if (asyncPlugins.hasError)
                          AppMobileSectionError(
                            key: const Key('mobile-plugins-error-state'),
                            title: '插件加载失败',
                            message: apiErrorMessage(
                              asyncPlugins.error!,
                              fallback: '插件加载失败，请稍后重试。',
                            ),
                            onRetry: _actions.refresh,
                            retryButtonKey: const Key(
                              'mobile-plugins-retry-button',
                            ),
                          )
                        else if (state == null || state.plugins.isEmpty)
                          const _MobilePluginsEmptyState(
                            key: Key('mobile-plugins-empty-state'),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (
                                var index = 0;
                                index < state.plugins.length;
                                index++
                              ) ...[
                                if (index > 0) SizedBox(height: spacing.sm),
                                _MobilePluginCard(
                                  plugin: state.plugins[index],
                                  update: state
                                      .updates[state.plugins[index].pluginId],
                                  busy: state.busyPluginIds.contains(
                                    state.plugins[index].pluginId,
                                  ),
                                  installing: state.isInstalling,
                                  checkingUpdates: state.isCheckingUpdates,
                                  onTap: () =>
                                      _openSettings(state.plugins[index]),
                                  onMore: () =>
                                      _showActions(state.plugins[index]),
                                ),
                              ],
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.md,
              spacing.sm,
              spacing.md,
              spacing.md,
            ),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                key: const Key('mobile-plugins-install-button'),
                label: '安装插件',
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.upload_file_outlined),
                isLoading: state?.isInstalling == true,
                onPressed:
                    asyncPlugins.isLoading || asyncPlugins.hasError || busy
                    ? null
                    : _actions.install,
              ),
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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: const AppEmptyState(
        icon: Icons.extension_outlined,
        title: '还没有安装插件',
        message: '点击下方「安装插件」上传 zip 插件包，安装后需重启容器才生效。',
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
    final disabled = busy || installing || checkingUpdates;
    final statusTone = plugin.enabled
        ? AppBadgeTone.success
        : AppBadgeTone.neutral;
    return Container(
      key: Key('mobile-plugin-card-${plugin.pluginId}'),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: Key('mobile-plugin-card-body-${plugin.pluginId}'),
                borderRadius: context.appRadius.lgBorder,
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
                                AppBadge(
                                  label: plugin.enabled ? '已启用' : '已停用',
                                  tone: statusTone,
                                  size: AppBadgeSize.compact,
                                ),
                                if (plugin.loadStatus == 'error')
                                  Tooltip(
                                    message: plugin.loadError ?? '插件加载失败',
                                    child: const AppBadge(
                                      label: '加载失败',
                                      tone: AppBadgeTone.error,
                                      size: AppBadgeSize.compact,
                                    ),
                                  ),
                                if (update != null)
                                  const AppBadge(
                                    label: '有更新',
                                    tone: AppBadgeTone.warning,
                                    size: AppBadgeSize.compact,
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
              tooltip: '更多操作',
              semanticLabel: '管理 ${plugin.displayName}',
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
            '选择要执行的插件操作',
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
            label: plugin.enabled ? '停用插件' : '启用插件',
            disabled: disabled,
            onTap: () => _select(context, _MobilePluginAction.toggle),
          ),
          if (update != null)
            _MobilePluginActionRow(
              key: Key('mobile-plugin-update-${plugin.pluginId}'),
              icon: Icons.system_update_outlined,
              label: '更新到 v${update!.version}',
              disabled: disabled,
              onTap: () => _select(context, _MobilePluginAction.update),
            ),
          _MobilePluginActionRow(
            key: Key('mobile-plugin-delete-${plugin.pluginId}'),
            icon: Icons.delete_outline_rounded,
            label: '删除插件',
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
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: context.appRadius.mdBorder,
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
