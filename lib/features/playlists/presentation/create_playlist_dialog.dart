import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/playlists/data/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/data/playlists_api.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

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
        builder:
            (dialogContext) => const CreatePlaylistDialog(
              presentation: CreatePlaylistDialogPresentation.dialog,
            ),
      );
    case CreatePlaylistDialogPresentation.bottomDrawer:
      return showAppBottomDrawer<PlaylistDto>(
        context: context,
        drawerKey: const Key('create-playlist-bottom-sheet'),
        // maxHeightFactor: 0.4,
        heightFactor: 0.4,
        builder:
            (sheetContext) => const CreatePlaylistDialog(
              presentation: CreatePlaylistDialogPresentation.bottomDrawer,
            ),
      );
  }
}

class CreatePlaylistDialog extends StatefulWidget {
  const CreatePlaylistDialog({
    super.key,
    this.presentation = CreatePlaylistDialogPresentation.dialog,
  });

  final CreatePlaylistDialogPresentation presentation;

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog> {
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
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '新建播放列表',
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
            hintText: '例如：稍后再看',
            validator:
                (value) =>
                    value == null || value.trim().isEmpty ? '请输入播放列表名称' : null,
          ),
          SizedBox(height: spacing.sm),
          AppTextField(
            fieldKey: const Key('create-playlist-description-field'),
            controller: _descriptionController,
            hintText: '描述可选',
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '取消',
                  onPressed:
                      _isSubmitting ? null : () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: const Key('create-playlist-submit-button'),
                  label: '创建',
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
    setState(() {
      _isSubmitting = true;
    });
    try {
      final playlist = await context.read<PlaylistsApi>().createPlaylist(
        name: _nameController.text,
        description: _descriptionController.text,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(playlist);
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '创建播放列表失败'));
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
