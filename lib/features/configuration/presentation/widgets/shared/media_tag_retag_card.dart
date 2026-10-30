import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_tags_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

class MediaTagRetagCard extends ConsumerStatefulWidget {
  const MediaTagRetagCard({super.key});

  @override
  ConsumerState<MediaTagRetagCard> createState() => _MediaTagRetagCardState();
}

class _MediaTagRetagCardState extends ConsumerState<MediaTagRetagCard> {
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.mediaTagsRetagConfirmTitle,
      message: l10n.mediaTagsRetagConfirmMessage,
      confirmLabel: l10n.mediaTagsRetagAction,
      dialogKey: const Key('media-tag-retag-confirm-dialog'),
      confirmKey: const Key('media-tag-retag-confirm'),
      cancelKey: const Key('media-tag-retag-cancel'),
    );
    if (!confirmed || !mounted) return;
    setState(() => _isSubmitting = true);
    try {
      await ref.read(mediaTagsProvider.notifier).triggerRetag();
      if (mounted) showToast(l10n.mediaTagsRetagSubmitted);
    } catch (error) {
      if (mounted) {
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.mediaTagsRetagFailed,
            l10n: l10n,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return AppContentCard(
      key: const Key('media-tag-retag-card'),
      title: l10n.mediaTagsRetagTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.mediaTagsRetagDescription,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.md),
          AppButton(
            key: const Key('media-tag-retag-submit'),
            label: l10n.mediaTagsRetagAction,
            size: AppButtonSize.small,
            icon: const Icon(Icons.refresh_rounded),
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
