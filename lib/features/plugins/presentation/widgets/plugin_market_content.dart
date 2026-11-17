import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/format/app_number_format.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/plugin_management_actions.dart';
import 'package:sakuramedia/features/plugins/presentation/plugin_placeholders.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_market_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_market_state.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/widgets/plugin_market_item_card.dart';
import 'package:sakuramedia/features/plugins/presentation/widgets/plugin_market_search_field.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';

/// 插件市场内容：桌面分栏与移动页面共用，仅通过 [mobile] 区分布局。
class PluginMarketContent extends ConsumerWidget {
  const PluginMarketContent({super.key, required this.mobile});

  final bool mobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final prefix = mobile ? 'mobile-plugin-market' : 'plugin-market';
    final asyncMarket = ref.watch(pluginMarketProvider);
    final installedById = _installedPluginsById(ref);
    final actions = PluginManagementActions(context: context, ref: ref);
    final marketState = asyncMarket.value;
    final error = marketState == null && asyncMarket.hasError
        ? asyncMarket.error
        : null;
    final errorMessage = error == null
        ? null
        : apiErrorMessage(
            error,
            fallback: l10n.pluginMarketLoadFailedFallback,
            l10n: l10n,
          );

    if (!mobile && error != null) {
      return AppSectionError(
        key: Key('$prefix-error'),
        title: l10n.pluginMarketLoadFailed,
        message: errorMessage!,
        onRetry: actions.refreshMarket,
      );
    }

    final isLoading = marketState == null;
    final state = marketState ?? pluginMarketPlaceholderState();
    final notice = mobile
        ? AppNoticeCard(
            key: Key('$prefix-notice'),
            leadingIcon: Icons.storefront_outlined,
            title: l10n.pluginMarketTitle,
            description: l10n.pluginMarketDescription,
            stats: [
              AppNoticeStat(
                label: l10n.pluginMarketInstallable,
                value: formatAppCount(marketState?.catalog.plugins.length ?? 0),
                valueSize: AppTextSize.s18,
              ),
              AppNoticeStat(
                label: l10n.pluginMarketUpdatable,
                value: formatAppCount(_updateCount(marketState, installedById)),
                valueSize: AppTextSize.s18,
              ),
            ],
          )
        : AppNoticeCard(
            key: Key('$prefix-notice'),
            leadingIcon: Icons.storefront_outlined,
            description: l10n.pluginMarketDescription,
          );
    final search = PluginMarketSearchField(
      fieldKey: Key('$prefix-search-field'),
    );

    Widget body;
    if (error != null) {
      body = AppMobileSectionError(
        key: Key('$prefix-error-state'),
        title: l10n.pluginMarketLoadFailed,
        message: errorMessage!,
        onRetry: actions.refreshMarket,
        retryButtonKey: Key('$prefix-retry-button'),
      );
    } else if (mobile) {
      body = AppSkeletonizer(
        enabled: isLoading,
        child: _buildItems(context, l10n, prefix, state, installedById),
      );
    } else {
      body = _buildItems(context, l10n, prefix, state, installedById);
    }

    final content = Column(
      crossAxisAlignment: mobile
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        notice,
        SizedBox(height: mobile ? spacing.md : spacing.lg),
        if (mobile)
          search
        else
          Row(
            children: [
              Expanded(child: search),
              SizedBox(width: spacing.sm),
              AppButton(
                key: const Key('plugin-market-refresh-button'),
                label: l10n.commonRefresh,
                size: AppButtonSize.small,
                icon: const Icon(Icons.refresh_rounded),
                isLoading: asyncMarket.isLoading,
                onPressed: state.busyPluginIds.isEmpty
                    ? actions.refreshMarket
                    : null,
              ),
            ],
          ),
        SizedBox(height: mobile ? spacing.md : spacing.lg),
        body,
      ],
    );

    if (!mobile) {
      return AppSkeletonizer(enabled: isLoading, child: content);
    }
    return ColoredBox(
      key: Key(prefix),
      color: context.appColors.surfaceCard,
      child: AppAdaptiveRefreshScrollView(
        onRefresh: actions.refreshMarket,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(top: spacing.sm, bottom: spacing.lg),
            sliver: SliverToBoxAdapter(child: content),
          ),
        ],
      ),
    );
  }

  Widget _buildItems(
    BuildContext context,
    AppLocalizations l10n,
    String prefix,
    PluginMarketState state,
    Map<String, PluginSummaryDto> installedById,
  ) {
    final spacing = context.appSpacing;
    final visiblePlugins = state.visiblePlugins;
    if (visiblePlugins.isEmpty) {
      final noKeyword = state.keyword.trim().isEmpty;
      return AppEmptyState(
        key: Key('$prefix-empty-state'),
        icon: Icons.storefront_outlined,
        title: noKeyword ? l10n.pluginMarketEmpty : l10n.pluginMarketNoMatch,
        message: noKeyword
            ? l10n.pluginMarketEmptyDescription
            : l10n.pluginMarketNoMatchDescription,
      );
    }
    final list = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: mobile
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < visiblePlugins.length; index++) ...[
          if (index > 0)
            mobile
                ? SizedBox(height: spacing.sm)
                : Divider(
                    height: 1,
                    indent: spacing.xl,
                    color: context.appColors.borderSubtle,
                  ),
          PluginMarketItemCard(
            plugin: visiblePlugins[index],
            installed: installedById[visiblePlugins[index].pluginId],
            busy: state.busyPluginIds.contains(visiblePlugins[index].pluginId),
            mobile: mobile,
          ),
        ],
      ],
    );
    if (mobile) {
      return list;
    }
    return AppContentCard(
      key: const Key('plugin-market-list-card'),
      title: l10n.pluginMarketInstallablePlugins,
      headerTrailing: AppBadge(
        label: l10n.pluginsCount(visiblePlugins.length),
        tone: AppBadgeTone.neutral,
      ),
      padding: EdgeInsets.all(spacing.lg),
      headerBottomSpacing: spacing.sm,
      child: list,
    );
  }
}

int _updateCount(
  PluginMarketState? state,
  Map<String, PluginSummaryDto> installedById,
) {
  if (state == null) {
    return 0;
  }
  return state.catalog.plugins
      .where(
        (plugin) =>
            pluginMarketStatus(plugin, installedById[plugin.pluginId]) ==
            PluginMarketStatus.updateAvailable,
      )
      .length;
}

Map<String, PluginSummaryDto> _installedPluginsById(WidgetRef ref) {
  return <String, PluginSummaryDto>{
    for (final plugin
        in ref.watch(pluginsProvider).value?.plugins ??
            const <PluginSummaryDto>[])
      plugin.pluginId: plugin,
  };
}
