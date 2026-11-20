import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/language/app_language.dart';
import 'package:sakuramedia/app/language/providers/language_providers.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/auth/presentation/actions/auth_actions.dart';
import 'package:sakuramedia/features/external_player/presentation/widgets/external_player_settings_content.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/tv/tv_action_button.dart';
import 'package:sakuramedia/widgets/base/tv/tv_focusable.dart';
import 'package:sakuramedia/widgets/base/tv/tv_page.dart';
import 'package:sakuramedia/widgets/base/tv/tv_section_header.dart';

class TvSettingsPage extends ConsumerWidget {
  const TvSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = ref.watch(appLanguageControllerProvider);
    final sessionStore = ref.watch(sessionStoreProvider);
    return TvPagePadding(
      child: ListView(
        key: const Key('tv-settings-page'),
        children: [
          TvPageHeader(title: l10n.routeConfigurationTitle),
          SizedBox(height: AppTvTokens.sectionGap),
          TvSectionHeader(title: l10n.loginServerAddress),
          SizedBox(height: context.appSpacing.md),
          _TvSettingsValue(message: sessionStore.baseUrl),
          SizedBox(height: AppTvTokens.sectionGap),
          TvSectionHeader(title: l10n.settingsLanguageTitle),
          SizedBox(height: context.appSpacing.md),
          Wrap(
            spacing: context.appSpacing.md,
            runSpacing: context.appSpacing.md,
            children: [
              _TvLanguageChoice(
                label: l10n.settingsLanguageSimplifiedChinese,
                selected: language == AppLanguage.zhCN,
                onPressed: () => ref
                    .read(appLanguageControllerProvider.notifier)
                    .setLanguage(AppLanguage.zhCN),
              ),
              _TvLanguageChoice(
                label: l10n.settingsLanguageEnglish,
                selected: language == AppLanguage.en,
                onPressed: () => ref
                    .read(appLanguageControllerProvider.notifier)
                    .setLanguage(AppLanguage.en),
              ),
            ],
          ),
          SizedBox(height: AppTvTokens.sectionGap),
          const ExternalPlayerSettingsContent(),
          SizedBox(height: AppTvTokens.sectionGap),
          Align(
            alignment: Alignment.centerLeft,
            child: TvActionButton(
              label: l10n.shellLogout,
              icon: Icons.logout_rounded,
              tone: TvActionButtonTone.secondary,
              onPressed: () => context.logOut(),
            ),
          ),
          const SizedBox(height: 64),
        ],
      ),
    );
  }
}

class _TvSettingsValue extends StatelessWidget {
  const _TvSettingsValue({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.appSpacing.lg),
      decoration: BoxDecoration(
        color: context.appColors.surfaceElevated,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Text(
        message,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s20,
          tone: AppTextTone.secondary,
        ),
      ),
    );
  }
}

class _TvLanguageChoice extends StatelessWidget {
  const _TvLanguageChoice({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onPressed: onPressed,
      borderRadius: context.appRadius.mdBorder,
      scale: 1.02,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.appSpacing.xl,
          vertical: context.appSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : context.appColors.surfaceElevated,
          borderRadius: context.appRadius.mdBorder,
          border: Border.all(color: context.appColors.borderStrong),
        ),
        child: Text(
          label,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s20,
            weight: selected ? AppTextWeight.semibold : AppTextWeight.regular,
            tone: selected ? AppTextTone.onMedia : AppTextTone.primary,
          ),
        ),
      ),
    );
  }
}
