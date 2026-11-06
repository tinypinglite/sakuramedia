import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/language/app_language.dart';
import 'package:sakuramedia/app/language/providers/language_providers.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_market_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/plugin_management_actions.dart';
import 'package:sakuramedia/features/plugins/presentation/plugin_placeholders.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_market_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_market_state.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';

/// 系统设置「插件」页的「插件市场」分栏：搜索、索引列表与安装 / 更新。
class DesktopPluginMarketSection extends ConsumerStatefulWidget {
  const DesktopPluginMarketSection({super.key});

  @override
  ConsumerState<DesktopPluginMarketSection> createState() =>
      _DesktopPluginMarketSectionState();
}

class _DesktopPluginMarketSectionState
    extends ConsumerState<DesktopPluginMarketSection> {
  late final TextEditingController _searchController;

  PluginManagementActions get _actions =>
      PluginManagementActions(context: context, ref: ref);

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(pluginMarketProvider).value?.keyword ?? '',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncMarket = ref.watch(pluginMarketProvider);
    final language = ref.watch(appLanguageControllerProvider);
    final installedById = <String, PluginSummaryDto>{
      for (final plugin
          in ref.watch(pluginsProvider).value?.plugins ??
              const <PluginSummaryDto>[])
        plugin.pluginId: plugin,
    };

    if (asyncMarket.hasError && asyncMarket.value == null) {
      return AppSectionError(
        key: const Key('plugin-market-error'),
        title: l10n.pluginMarketLoadFailed,
        message: apiErrorMessage(
          asyncMarket.error!,
          fallback: l10n.pluginMarketLoadFailedFallback,
          l10n: l10n,
        ),
        onRetry: _actions.refreshMarket,
      );
    }

    final isLoading = asyncMarket.value == null;
    final state = isLoading
        ? pluginMarketPlaceholderState()
        : asyncMarket.value!;
    return AppSkeletonizer(
      enabled: isLoading,
      child: _buildLoaded(
        context,
        state,
        installedById,
        asyncMarket.isLoading,
        language,
      ),
    );
  }

  Widget _buildLoaded(
    BuildContext context,
    PluginMarketState state,
    Map<String, PluginSummaryDto> installedById,
    bool isRefreshing,
    AppLanguage language,
  ) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final visiblePlugins = state.visiblePlugins;
    final busy = state.busyPluginIds.isNotEmpty;
    final rows = <Widget>[];
    for (var i = 0; i < visiblePlugins.length; i++) {
      final plugin = visiblePlugins[i];
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
        _MarketPluginRow(
          plugin: plugin,
          displayName: plugin.localizedDisplayName(language),
          description: plugin.localizedDescription(language),
          status: pluginMarketStatus(plugin, installedById[plugin.pluginId]),
          installedVersion: installedById[plugin.pluginId]?.version,
          busy: state.busyPluginIds.contains(plugin.pluginId),
          onInstall: () => _actions.installFromMarket(plugin),
          onUpgrade: () => _actions.upgradeFromMarket(
            plugin,
            installedById[plugin.pluginId]!.version,
          ),
          onCopyHomepage: () => _actions.copyHomepageFromMarket(plugin),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppNoticeCard(
          key: const Key('plugin-market-notice'),
          leadingIcon: Icons.storefront_outlined,
          description: l10n.pluginMarketDescription,
        ),
        SizedBox(height: spacing.lg),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                fieldKey: const Key('plugin-market-search-field'),
                controller: _searchController,
                hintText: l10n.pluginMarketSearchHint,
                prefix: Icon(
                  Icons.search_rounded,
                  size: context.appComponentTokens.iconSizeSm,
                  color: context.appTextPalette.muted,
                ),
                onChanged: ref.read(pluginMarketProvider.notifier).setKeyword,
              ),
            ),
            SizedBox(width: spacing.sm),
            AppButton(
              key: const Key('plugin-market-refresh-button'),
              label: l10n.commonRefresh,
              size: AppButtonSize.small,
              icon: const Icon(Icons.refresh_rounded),
              isLoading: isRefreshing,
              onPressed: busy ? null : _actions.refreshMarket,
            ),
          ],
        ),
        SizedBox(height: spacing.lg),
        if (visiblePlugins.isEmpty)
          AppEmptyState(
            key: const Key('plugin-market-empty-state'),
            icon: Icons.storefront_outlined,
            title: state.keyword.trim().isEmpty
                ? l10n.pluginMarketEmpty
                : l10n.pluginMarketNoMatch,
            message: state.keyword.trim().isEmpty
                ? l10n.pluginMarketEmptyDescription
                : l10n.pluginMarketNoMatchDescription,
          )
        else
          AppContentCard(
            key: const Key('plugin-market-list-card'),
            title: l10n.pluginMarketInstallablePlugins,
            headerTrailing: AppBadge(
              label: l10n.pluginsCount(visiblePlugins.length),
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

class _MarketPluginRow extends StatelessWidget {
  const _MarketPluginRow({
    required this.plugin,
    required this.displayName,
    required this.description,
    required this.status,
    required this.installedVersion,
    required this.busy,
    required this.onInstall,
    required this.onUpgrade,
    required this.onCopyHomepage,
  });

  final PluginMarketItemDto plugin;

  /// 当前语言下的插件名与简介，由父级解析后传入。
  final String displayName;
  final String description;
  final PluginMarketStatus status;
  final String? installedVersion;
  final bool busy;
  final VoidCallback onInstall;
  final VoidCallback onUpgrade;
  final VoidCallback onCopyHomepage;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final release = plugin.latest;
    return Padding(
      key: Key('plugin-market-row-${plugin.pluginId}'),
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
                        displayName,
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
                    SizedBox(width: spacing.sm),
                    AppBadge(
                      label: plugin.official
                          ? l10n.pluginMarketOfficial
                          : l10n.pluginMarketCommunity,
                      tone: plugin.official
                          ? AppBadgeTone.primary
                          : AppBadgeTone.neutral,
                      size: AppBadgeSize.compact,
                    ),
                  ],
                ),
                SizedBox(height: spacing.xs / 2),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.secondary,
                  ),
                ),
                SizedBox(height: spacing.xs / 2),
                Text(
                  _subtitle(l10n),
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
          if (plugin.homepageUrl != null) ...[
            AppIconButton(
              key: Key('plugin-market-copy-homepage-button-${plugin.pluginId}'),
              tooltip: l10n.pluginMarketCopyHomepage,
              semanticLabel: l10n.pluginMarketCopyHomepageSemantic(displayName),
              icon: const Icon(Icons.content_copy_rounded),
              onPressed: onCopyHomepage,
            ),
            SizedBox(width: spacing.xs),
          ],
          if (busy)
            const AppInlineSpinner()
          else
            switch (status) {
              PluginMarketStatus.notInstalled => AppButton(
                key: Key('plugin-market-install-button-${plugin.pluginId}'),
                label: l10n.pluginInstallConfirm,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.xSmall,
                onPressed: release == null ? null : onInstall,
              ),
              PluginMarketStatus.updateAvailable => AppButton(
                key: Key('plugin-market-upgrade-button-${plugin.pluginId}'),
                label: l10n.pluginUpgradeConfirm,
                variant: AppButtonVariant.primary,
                size: AppButtonSize.xSmall,
                onPressed: onUpgrade,
              ),
              PluginMarketStatus.installed => AppStatusChip(
                label: l10n.pluginMarketInstalled,
                palette: AppStatusChipPalette.forSemantic(
                  AppStatusSemantic.success,
                ),
                dense: true,
              ),
            },
        ],
      ),
    );
  }

  String _subtitle(AppLocalizations l10n) {
    final version = plugin.latest?.version;
    if (status == PluginMarketStatus.updateAvailable &&
        installedVersion != null) {
      return l10n.pluginMarketInstalledVersion(
        installedVersion!,
        version ?? '-',
      );
    }
    if (status == PluginMarketStatus.installed && installedVersion != null) {
      return l10n.pluginMarketInstalledAuthor(installedVersion!, plugin.author);
    }
    return 'v${version ?? '-'} · ${plugin.author}';
  }
}
