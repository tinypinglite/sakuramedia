import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/auth/presentation/actions/auth_actions.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/language_settings_content.dart';
import 'package:sakuramedia/features/external_player/presentation/widgets/external_player_settings_content.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/tv/tv_page.dart';

class TvSettingsPage extends ConsumerWidget {
  const TvSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sessionStore = ref.watch(sessionStoreProvider);
    return TvPagePadding(
      child: ListView(
        key: const Key('tv-settings-page'),
        children: [
          TvPageHeader(title: l10n.routeConfigurationTitle),
          SizedBox(height: AppTvTokens.sectionGap),
          AppSettingsGroup(
            header: l10n.loginServerAddress,
            children: [
              AppSettingCell(
                icon: Icons.dns_outlined,
                title: sessionStore.baseUrl,
              ),
            ],
          ),
          SizedBox(height: AppTvTokens.sectionGap),
          const LanguageSettingsContent(),
          SizedBox(height: AppTvTokens.sectionGap),
          const ExternalPlayerSettingsContent(),
          SizedBox(height: AppTvTokens.sectionGap),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: l10n.shellLogout,
              icon: const Icon(Icons.logout_rounded),
              size: AppButtonSize.tvLarge,
              variant: AppButtonVariant.secondary,
              onPressed: () => context.logOut(),
            ),
          ),
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}
