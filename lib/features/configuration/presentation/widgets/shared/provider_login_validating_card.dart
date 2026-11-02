import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

const _slowValidationHintDelay = Duration(seconds: 5);

class ProviderLoginValidatingCard extends StatefulWidget {
  const ProviderLoginValidatingCard({super.key, required this.providerName});

  final String providerName;

  @override
  State<ProviderLoginValidatingCard> createState() =>
      _ProviderLoginValidatingCardState();
}

class _ProviderLoginValidatingCardState
    extends State<ProviderLoginValidatingCard> {
  Timer? _slowHintTimer;
  bool _showSlowHint = false;

  @override
  void initState() {
    super.initState();
    _slowHintTimer = Timer(_slowValidationHintDelay, () {
      if (!mounted) return;
      setState(() => _showSlowHint = true);
    });
  }

  @override
  void dispose() {
    _slowHintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final message = _showSlowHint
        ? l10n.providerLoginValidatingSlow(widget.providerName)
        : l10n.providerLoginValidating(widget.providerName);

    return AbsorbPointer(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(spacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                key: const Key('provider-login-validating-card'),
                color: colors.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: context.appRadius.lgBorder,
                  side: BorderSide(color: colors.borderSubtle),
                ),
                child: Padding(
                  padding: EdgeInsets.all(spacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          key: Key('provider-login-validating-indicator'),
                          strokeWidth: 3,
                        ),
                      ),
                      SizedBox(height: spacing.md),
                      Text(
                        l10n.providerLoginValidatingTitle,
                        key: const Key('provider-login-validating-title'),
                        textAlign: TextAlign.center,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s16,
                          weight: AppTextWeight.semibold,
                          tone: AppTextTone.primary,
                        ),
                      ),
                      SizedBox(height: spacing.sm),
                      Text(
                        message,
                        key: const Key('provider-login-validating-message'),
                        textAlign: TextAlign.center,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          tone: AppTextTone.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
