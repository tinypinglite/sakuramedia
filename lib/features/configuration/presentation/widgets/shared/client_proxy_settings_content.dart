import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/providers/network_proxy_providers.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/domain/settings/network_proxy_dialog.dart';

/// 客户端代理设置：说明代理的适用范围，并提供代理地址编辑入口。
class ClientProxySettingsContent extends ConsumerWidget {
  const ClientProxySettingsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final config = ref.watch(networkProxyControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.clientProxyDescription,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        AppSettingsGroup(
          children: [
            AppSettingCell(
              key: const Key('configuration-client-proxy-entry'),
              icon: Icons.settings_ethernet_rounded,
              title: l10n.clientProxyTitle,
              subtitle: config?.displayAddress ?? l10n.clientProxyNotConfigured,
              trailing: const AppSettingCellChevron(),
              onTap: () => unawaited(showNetworkProxyDialog(context)),
            ),
          ],
        ),
      ],
    );
  }
}
