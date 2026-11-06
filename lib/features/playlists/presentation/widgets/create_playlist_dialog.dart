import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';

enum CreatePlaylistDialogPresentation { dialog, bottomDrawer }

Future<PlaylistDto?> showCreatePlaylistDialog(
  BuildContext context, {
  CreatePlaylistDialogPresentation presentation =
      CreatePlaylistDialogPresentation.dialog,
}) {
  switch (presentation) {
    case CreatePlaylistDialogPresentation.dialog:
      return showDialog<PlaylistDto>(
        context: context,
        builder: (dialogContext) => const CreatePlaylistDialog(
          presentation: CreatePlaylistDialogPresentation.dialog,
        ),
      );
    case CreatePlaylistDialogPresentation.bottomDrawer:
      return showAppBottomDrawer<PlaylistDto>(
        context: context,
        drawerKey: const Key('create-playlist-bottom-sheet'),
        heightFactor: 0.7,
        builder: (sheetContext) => const CreatePlaylistDialog(
          presentation: CreatePlaylistDialogPresentation.bottomDrawer,
        ),
      );
  }
}

class CreatePlaylistDialog extends ConsumerStatefulWidget {
  const CreatePlaylistDialog({
    super.key,
    this.presentation = CreatePlaylistDialogPresentation.dialog,
  });

  final CreatePlaylistDialogPresentation presentation;

  @override
  ConsumerState<CreatePlaylistDialog> createState() =>
      _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends ConsumerState<CreatePlaylistDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.presentation == CreatePlaylistDialogPresentation.dialog) {
      return AppDesktopDialog(
        width: context.appComponentTokens.playlistDialogWidth,
        child: _buildFormContent(context),
      );
    }

    return SingleChildScrollView(child: _buildFormContent(context));
  }

  Widget _buildFormContent(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.playlistCreateTitle,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('create-playlist-name-field'),
            controller: _nameController,
            hintText: l10n.playlistNameHint,
            validator: (value) => value == null || value.trim().isEmpty
                ? l10n.playlistNameRequired
                : null,
          ),
          SizedBox(height: spacing.sm),
          AppTextField(
            fieldKey: const Key('create-playlist-description-field'),
            controller: _descriptionController,
            hintText: l10n.playlistDescriptionHint,
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.commonCancel,
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: const Key('create-playlist-submit-button'),
                  label: l10n.playlistCreateAction,
                  variant: AppButtonVariant.primary,
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isSubmitting = true;
    });
    try {
      final playlist = await ref
          .read(playlistsApiProvider)
          .createPlaylist(
            name: _nameController.text,
            description: _descriptionController.text,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(playlist);
    } catch (error) {
      showToast(
        apiErrorMessage(error, fallback: l10n.playlistCreateFailed, l10n: l10n),
        tone: AppToastTone.error,
      );
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
