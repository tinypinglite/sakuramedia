import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/language/providers/language_providers.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_market_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/plugin_management_actions.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_market_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

/// 插件市场条目：桌面为列表行，移动端为独立卡片。
class PluginMarketItemCard extends ConsumerWidget {
  const PluginMarketItemCard({
    super.key,
    required this.plugin,
    required this.installed,
    required this.busy,
    required this.mobile,
  });

  final PluginMarketItemDto plugin;
  final PluginSummaryDto? installed;
  final bool busy;
  final bool mobile;

  String get _keyPrefix => mobile ? 'mobile-plugin-market' : 'plugin-market';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final language = ref.watch(appLanguageControllerProvider);
    final actions = PluginManagementActions(context: context, ref: ref);
    final status = pluginMarketStatus(plugin, installed);
    final displayName = plugin.localizedDisplayName(language);

    final icon = mobile
        ? Container(
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
          )
        : Icon(
            Icons.extension_outlined,
            size: context.appComponentTokens.iconSizeMd,
            color: context.appTextPalette.muted,
          );

    final title = mobile
        ? Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [_titleText(context, displayName), _badge(l10n)],
          )
        : Row(
            children: [
              Flexible(child: _titleText(context, displayName)),
              SizedBox(width: spacing.sm),
              _badge(l10n),
            ],
          );

    final description = Text(
      plugin.localizedDescription(language),
      maxLines: mobile ? 3 : 2,
      overflow: TextOverflow.ellipsis,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        tone: AppTextTone.secondary,
      ),
    );

    final actionGroup = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (plugin.homepageUrl != null) ...[
          AppIconButton(
            key: Key('$_keyPrefix-copy-homepage-button-${plugin.pluginId}'),
            tooltip: l10n.pluginMarketCopyHomepage,
            semanticLabel: l10n.pluginMarketCopyHomepageSemantic(displayName),
            icon: const Icon(Icons.content_copy_rounded),
            onPressed: () => actions.copyHomepageFromMarket(plugin),
          ),
          if (!mobile) SizedBox(width: spacing.xs),
        ],
        if (busy)
          const AppInlineSpinner()
        else
          _statusAction(context, l10n, actions, status),
      ],
    );

    if (!mobile) {
      return Padding(
        key: Key('plugin-market-row-${plugin.pluginId}'),
        padding: EdgeInsets.symmetric(vertical: spacing.md),
        child: Row(
          children: [
            icon,
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  SizedBox(height: spacing.xs / 2),
                  description,
                  SizedBox(height: spacing.xs / 2),
                  _subtitleText(context, l10n),
                ],
              ),
            ),
            SizedBox(width: spacing.md),
            actionGroup,
          ],
        ),
      );
    }

    return AppContentCard(
      key: Key('mobile-plugin-market-card-${plugin.pluginId}'),
      padding: EdgeInsets.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    SizedBox(height: spacing.xs / 2),
                    description,
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Row(
            children: [
              Expanded(child: _subtitleText(context, l10n)),
              actionGroup,
            ],
          ),
        ],
      ),
    );
  }

  Widget _titleText(BuildContext context, String displayName) {
    return Text(
      displayName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s14,
        weight: AppTextWeight.medium,
        tone: AppTextTone.primary,
      ),
    );
  }

  Widget _badge(AppLocalizations l10n) {
    return AppBadge(
      label: plugin.official
          ? l10n.pluginMarketOfficial
          : l10n.pluginMarketCommunity,
      tone: plugin.official ? AppBadgeTone.primary : AppBadgeTone.neutral,
      size: AppBadgeSize.compact,
    );
  }

  Widget _subtitleText(BuildContext context, AppLocalizations l10n) {
    return Text(
      _subtitle(l10n),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        tone: AppTextTone.muted,
      ),
    );
  }

  Widget _statusAction(
    BuildContext context,
    AppLocalizations l10n,
    PluginManagementActions actions,
    PluginMarketStatus status,
  ) {
    final release = plugin.latest;
    return switch (status) {
      PluginMarketStatus.notInstalled => AppButton(
        key: Key('$_keyPrefix-install-button-${plugin.pluginId}'),
        label: l10n.pluginInstallConfirm,
        variant: AppButtonVariant.primary,
        size: AppButtonSize.xSmall,
        onPressed: release == null
            ? null
            : () => actions.installFromMarket(plugin),
      ),
      PluginMarketStatus.updateAvailable => AppButton(
        key: Key('$_keyPrefix-upgrade-button-${plugin.pluginId}'),
        label: l10n.pluginUpgradeConfirm,
        variant: AppButtonVariant.primary,
        size: AppButtonSize.xSmall,
        onPressed: () => actions.upgradeFromMarket(plugin, installed!.version),
      ),
      PluginMarketStatus.installed => AppStatusChip(
        label: l10n.pluginMarketInstalled,
        palette: AppStatusChipPalette.forSemantic(AppStatusSemantic.success),
        dense: true,
      ),
    };
  }

  String _subtitle(AppLocalizations l10n) {
    final status = pluginMarketStatus(plugin, installed);
    final version = plugin.latest?.version;
    if (status == PluginMarketStatus.updateAvailable && installed != null) {
      return l10n.pluginMarketInstalledVersion(
        installed!.version,
        version ?? '-',
      );
    }
    if (status == PluginMarketStatus.installed && installed != null) {
      return l10n.pluginMarketInstalledAuthor(
        installed!.version,
        plugin.author,
      );
    }
    return 'v${version ?? '-'} · ${plugin.author}';
  }
}
