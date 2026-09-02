import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/pages/desktop/plugin_settings_dialog.dart';
import 'package:sakuramedia/features/plugins/presentation/plugin_management_actions.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_switch.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_skeleton.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';

/// 系统设置里的「插件」页：列表、zip 安装、启停、删除与 JSON 配置编辑。
class DesktopPluginsSection extends ConsumerStatefulWidget {
  const DesktopPluginsSection({super.key, required this.active});

  final bool active;

  @override
  ConsumerState<DesktopPluginsSection> createState() =>
      _DesktopPluginsSectionState();
}

class _DesktopPluginsSectionState extends ConsumerState<DesktopPluginsSection> {
  PluginManagementActions get _actions =>
      PluginManagementActions(context: context, ref: ref);

  void _openSettings(PluginSummaryDto plugin) {
    unawaited(showPluginSettingsDialog(context, plugin: plugin));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return const SizedBox.shrink();
    }
    final asyncPlugins = ref.watch(pluginsProvider);
    final content = asyncPlugins.when(
      loading: () => const AppSectionSkeleton(lineCount: 4),
      error: (error, _) => AppSectionError(
        title: '插件加载失败',
        message: apiErrorMessage(error, fallback: '插件加载失败，请稍后重试。'),
        onRetry: _actions.refresh,
      ),
      data: (state) => _buildLoaded(context, state),
    );
    return AppPageRefreshScope(onRefresh: _actions.refresh, child: content);
  }

  Widget _buildLoaded(BuildContext context, PluginsState state) {
    final spacing = context.appSpacing;
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
          onToggle: (enabled) => _actions.toggle(plugin, enabled),
          onUpgrade: (update) => _actions.upgrade(plugin, update),
          onRemove: () => _actions.remove(plugin),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppNoticeCard(
          key: Key('plugins-restart-notice'),
          leadingIcon: Icons.info_outline_rounded,
          description: '插件安装、更新、启停、删除或配置修改后，需重启容器才生效。',
        ),
        SizedBox(height: spacing.lg),
        Row(
          children: [
            AppButton(
              key: const Key('plugins-check-updates-button'),
              label: '检查更新',
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
            AppButton(
              key: const Key('plugins-install-button'),
              label: '安装插件',
              variant: AppButtonVariant.primary,
              size: AppButtonSize.small,
              icon: const Icon(Icons.upload_file_outlined),
              isLoading: state.isInstalling,
              onPressed: state.isInstalling || state.isCheckingUpdates
                  ? null
                  : _actions.install,
            ),
            SizedBox(width: spacing.md),
            Text(
              '支持上传 .zip 插件包',
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
          const AppEmptyState(
            key: Key('plugins-empty-state'),
            icon: Icons.extension_outlined,
            title: '还没有安装插件',
            message: '点击上方「安装插件」上传 zip 插件包，安装后需重启容器才生效。',
          )
        else
          AppContentCard(
            key: const Key('plugins-list-card'),
            title: '已安装插件',
            headerTrailing: AppBadge(
              label: '${state.plugins.length} 个',
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
  final ValueChanged<bool> onToggle;
  final ValueChanged<PluginReleaseUpdate> onUpgrade;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final disabled = busy || installing || checkingUpdates;
    return InkWell(
      key: Key('plugin-row-${plugin.pluginId}'),
      onTap: disabled ? null : onTap,
      borderRadius: context.appRadius.mdBorder,
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
                          message: plugin.loadError ?? '插件加载失败',
                          child: const AppBadge(
                            label: '加载失败',
                            tone: AppBadgeTone.error,
                            size: AppBadgeSize.compact,
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
                label: '更新',
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
            AppIconButton(
              key: Key('plugin-remove-button-${plugin.pluginId}'),
              tooltip: '删除插件',
              semanticLabel: '删除 ${plugin.displayName}',
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
