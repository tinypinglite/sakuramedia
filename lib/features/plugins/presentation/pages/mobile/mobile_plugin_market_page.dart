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
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';

/// 移动端插件市场页：搜索、索引卡片列表与安装 / 更新。
class MobilePluginMarketPage extends ConsumerStatefulWidget {
  const MobilePluginMarketPage({super.key});

  @override
  ConsumerState<MobilePluginMarketPage> createState() =>
      _MobilePluginMarketPageState();
}

class _MobilePluginMarketPageState
    extends ConsumerState<MobilePluginMarketPage> {
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
    final asyncMarket = ref.watch(pluginMarketProvider);
    final language = ref.watch(appLanguageControllerProvider);
    final installedById = <String, PluginSummaryDto>{
      for (final plugin
          in ref.watch(pluginsProvider).value?.plugins ??
              const <PluginSummaryDto>[])
        plugin.pluginId: plugin,
    };
    final state = asyncMarket.value;
    final visiblePlugins =
        state?.visiblePlugins ?? const <PluginMarketItemDto>[];
    final updateCount = state == null
        ? 0
        : state.catalog.plugins
              .where(
                (plugin) =>
                    pluginMarketStatus(plugin, installedById[plugin.pluginId]) ==
                    PluginMarketStatus.updateAvailable,
              )
              .length;
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);

    return ColoredBox(
      key: const Key('mobile-plugin-market'),
      color: context.appColors.surfaceCard,
      child: AppAdaptiveRefreshScrollView(
        onRefresh: _actions.refreshMarket,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(top: spacing.sm, bottom: spacing.lg),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppNoticeCard(
                    key: const Key('mobile-plugin-market-notice'),
                    leadingIcon: Icons.storefront_outlined,
                    title: l10n.pluginMarketTitle,
                    description: l10n.pluginMarketDescription,
                    stats: [
                      AppNoticeStat(
                        label: l10n.pluginMarketInstallable,
                        value: '${state?.catalog.plugins.length ?? 0}',
                        valueSize: AppTextSize.s18,
                      ),
                      AppNoticeStat(
                        label: l10n.pluginMarketUpdatable,
                        value: '$updateCount',
                        valueSize: AppTextSize.s18,
                      ),
                    ],
                  ),
                  SizedBox(height: spacing.md),
                  AppTextField(
                    fieldKey: const Key('mobile-plugin-market-search-field'),
                    controller: _searchController,
                    hintText: l10n.pluginMarketSearchHint,
                    prefix: Icon(
                      Icons.search_rounded,
                      size: context.appComponentTokens.iconSizeSm,
                      color: context.appTextPalette.muted,
                    ),
                    onChanged: ref
                        .read(pluginMarketProvider.notifier)
                        .setKeyword,
                  ),
                  SizedBox(height: spacing.md),
                  ..._buildBody(
                    context,
                    asyncMarket,
                    state,
                    visiblePlugins,
                    installedById,
                    language,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBody(
    BuildContext context,
    AsyncValue<PluginMarketState> asyncMarket,
    PluginMarketState? state,
    List<PluginMarketItemDto> visiblePlugins,
    Map<String, PluginSummaryDto> installedById,
    AppLanguage language,
  ) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    if (state == null && asyncMarket.hasError) {
      return [
        AppMobileSectionError(
          key: const Key('mobile-plugin-market-error-state'),
          title: l10n.pluginMarketLoadFailed,
          message: apiErrorMessage(
            asyncMarket.error!,
            fallback: l10n.pluginMarketLoadFailedFallback,
            l10n: l10n,
          ),
          onRetry: _actions.refreshMarket,
          retryButtonKey: const Key('mobile-plugin-market-retry-button'),
        ),
      ];
    }
    if (state == null) {
      final placeholders = pluginMarketPlaceholderState().catalog.plugins;
      return [
        AppSkeletonizer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < placeholders.length; index++) ...[
                if (index > 0) SizedBox(height: spacing.sm),
                _MobileMarketPluginCard(
                  plugin: placeholders[index],
                  displayName: placeholders[index].localizedDisplayName(
                    language,
                  ),
                  description: placeholders[index].localizedDescription(
                    language,
                  ),
                  status: PluginMarketStatus.notInstalled,
                  installedVersion: null,
                  busy: false,
                  onInstall: _noop,
                  onUpgrade: _noop,
                  onCopyHomepage: _noop,
                ),
              ],
            ],
          ),
        ),
      ];
    }
    if (visiblePlugins.isEmpty) {
      return [
        AppEmptyState(
          key: const Key('mobile-plugin-market-empty-state'),
          icon: Icons.storefront_outlined,
          title: state.keyword.trim().isEmpty
              ? l10n.pluginMarketEmpty
              : l10n.pluginMarketNoMatch,
          message: state.keyword.trim().isEmpty
              ? l10n.pluginMarketEmptyDescription
              : l10n.pluginMarketNoMatchDescription,
        ),
      ];
    }
    return [
      for (var index = 0; index < visiblePlugins.length; index++) ...[
        if (index > 0) SizedBox(height: spacing.sm),
        _MobileMarketPluginCard(
          plugin: visiblePlugins[index],
          displayName: visiblePlugins[index].localizedDisplayName(language),
          description: visiblePlugins[index].localizedDescription(language),
          status: pluginMarketStatus(
            visiblePlugins[index],
            installedById[visiblePlugins[index].pluginId],
          ),
          installedVersion:
              installedById[visiblePlugins[index].pluginId]?.version,
          busy: state.busyPluginIds.contains(visiblePlugins[index].pluginId),
          onInstall: () => _actions.installFromMarket(visiblePlugins[index]),
          onUpgrade: () => _actions.upgradeFromMarket(
            visiblePlugins[index],
            installedById[visiblePlugins[index].pluginId]!.version,
          ),
          onCopyHomepage: () =>
              _actions.copyHomepageFromMarket(visiblePlugins[index]),
        ),
      ],
    ];
  }

  static void _noop() {}
}

class _MobileMarketPluginCard extends StatelessWidget {
  const _MobileMarketPluginCard({
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
    return AppContentCard(
      key: Key('mobile-plugin-market-card-${plugin.pluginId}'),
      title: null,
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: context.appComponentTokens.iconSizeXl + spacing.md,
                height: context.appComponentTokens.iconSizeXl + spacing.md,
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
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  _subtitle(l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.muted,
                  ),
                ),
              ),
              if (plugin.homepageUrl != null)
                AppIconButton(
                  key: Key(
                    'mobile-plugin-market-copy-homepage-button-'
                    '${plugin.pluginId}',
                  ),
                  tooltip: l10n.pluginMarketCopyHomepage,
                  semanticLabel: l10n.pluginMarketCopyHomepageSemantic(
                    displayName,
                  ),
                  icon: const Icon(Icons.content_copy_rounded),
                  onPressed: onCopyHomepage,
                ),
              if (busy)
                const AppInlineSpinner()
              else
                switch (status) {
                  PluginMarketStatus.notInstalled => AppButton(
                    key: Key(
                      'mobile-plugin-market-install-button-${plugin.pluginId}',
                    ),
                    label: l10n.pluginInstallConfirm,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.xSmall,
                    onPressed: release == null ? null : onInstall,
                  ),
                  PluginMarketStatus.updateAvailable => AppButton(
                    key: Key(
                      'mobile-plugin-market-upgrade-button-${plugin.pluginId}',
                    ),
                    label: l10n.pluginUpgradeConfirm,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.xSmall,
                    onPressed: onUpgrade,
                  ),
                  PluginMarketStatus.installed => AppBadge(
                    label: l10n.pluginMarketInstalled,
                    tone: AppBadgeTone.success,
                    size: AppBadgeSize.compact,
                  ),
                },
            ],
          ),
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
      return l10n.pluginMarketInstalledAuthor(
        installedVersion!,
        plugin.author,
      );
    }
    return 'v${version ?? '-'} · ${plugin.author}';
  }
}
