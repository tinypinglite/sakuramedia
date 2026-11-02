import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_login_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';

class MediaProviderLoginCard extends StatelessWidget {
  const MediaProviderLoginCard({
    super.key,
    required this.provider,
    required this.session,
    required this.manualMode,
    required this.isBusy,
    required this.onLogin,
    required this.onUseManual,
  });

  final MediaProviderDto provider;
  final ProviderLoginSessionDto? session;
  final bool manualMode;
  final bool isBusy;
  final VoidCallback onLogin;
  final VoidCallback onUseManual;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final accountLabel = session?.accountLabel;
    final status = session == null
        ? null
        : accountLabel == null || accountLabel.isEmpty
        ? l10n.providerLoginSuccessWithoutAccount
        : l10n.providerLoginSuccess(accountLabel);

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.noticeSurface,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                manualMode ? Icons.key_rounded : Icons.login_rounded,
                size: context.appComponentTokens.iconSizeMd,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session != null
                          ? status!
                          : manualMode
                          ? l10n.providerLoginManualActive
                          : l10n.providerLoginTitle(provider.displayName),
                      key: const Key('media-library-provider-login-status'),
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      manualMode
                          ? l10n.providerLoginManualDescription
                          : l10n.providerLoginDescription,
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
          SizedBox(height: spacing.md),
          Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: [
              if (!manualMode)
                AppButton(
                  key: const Key('media-library-provider-login-button'),
                  label: session == null
                      ? l10n.providerLoginAction
                      : l10n.providerLoginAgain,
                  icon: const Icon(Icons.open_in_new_rounded),
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.small,
                  onPressed: isBusy ? null : onLogin,
                ),
              if (!manualMode)
                AppButton(
                  key: const Key('media-library-provider-manual-toggle'),
                  label: l10n.providerLoginUseManual,
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.small,
                  onPressed: isBusy ? null : onUseManual,
                )
              else
                AppButton(
                  key: const Key('media-library-provider-web-login-toggle'),
                  label: l10n.providerLoginUseWeb,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: isBusy ? null : onLogin,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
