import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';

/// 「编辑播放列表」弹窗形态；与 [showCreatePlaylistDialog] 对齐。
enum EditPlaylistDialogPresentation { dialog, bottomDrawer }

/// 打开「编辑播放列表」弹窗——桌面走 [AppDesktopDialog]、移动走 [showAppBottomDrawer]。
///
/// 提交成功返回后端最新 [PlaylistDto]；取消/关闭返回 `null`。
Future<PlaylistDto?> showEditPlaylistDialog(
  BuildContext context, {
  required PlaylistDto playlist,
  EditPlaylistDialogPresentation presentation =
      EditPlaylistDialogPresentation.dialog,
}) {
  switch (presentation) {
    case EditPlaylistDialogPresentation.dialog:
      return showAppDialog<PlaylistDto>(
        context: context,
        builder: (dialogContext) => EditPlaylistDialog(
          playlist: playlist,
          presentation: EditPlaylistDialogPresentation.dialog,
        ),
      );
    case EditPlaylistDialogPresentation.bottomDrawer:
      return showAppBottomDrawer<PlaylistDto>(
        context: context,
        drawerKey: const Key('playlist-edit-drawer'),
        maxHeightFactor: 0.62,
        builder: (sheetContext) => EditPlaylistDialog(
          playlist: playlist,
          presentation: EditPlaylistDialogPresentation.bottomDrawer,
        ),
      );
  }
}

class EditPlaylistDialog extends ConsumerStatefulWidget {
  const EditPlaylistDialog({
    super.key,
    required this.playlist,
    this.presentation = EditPlaylistDialogPresentation.dialog,
  });

  final PlaylistDto playlist;
  final EditPlaylistDialogPresentation presentation;

  @override
  ConsumerState<EditPlaylistDialog> createState() => _EditPlaylistDialogState();
}

class _EditPlaylistDialogState extends ConsumerState<EditPlaylistDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isSubmitting = false;
  bool _hasAttemptedSubmit = false;

  bool get _isDialog =>
      widget.presentation == EditPlaylistDialogPresentation.dialog;

  static const Key _nameFieldKey = Key('playlist-edit-name-field');
  static const Key _descriptionFieldKey = Key(
    'playlist-edit-description-field',
  );
  static const Key _submitKey = Key('playlist-edit-submit-button');

  AutovalidateMode get _autovalidateMode => _hasAttemptedSubmit
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playlist.name);
    _descriptionController = TextEditingController(
      text: widget.playlist.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDialog) {
      return AppDesktopDialog(
        width: context.appComponentTokens.playlistDialogWidth,
        child: _buildFormContent(context),
      );
    }
    // 键盘 viewInsets 由 AppBottomDrawerSurface 统一处理，这里不重复贴 padding，
    // 否则会出现「双份 bottom padding」把表单顶到远高于键盘的位置。
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
            l10n.playlistEditTitle,
            style: resolveAppTextStyle(
              context,
              size: _isDialog ? AppTextSize.s18 : AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            l10n.playlistEditDescription,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.lg),
          AppTextField(
            fieldKey: _nameFieldKey,
            controller: _nameController,
            hintText: l10n.playlistNameHint,
            enabled: !_isSubmitting,
            autovalidateMode: _autovalidateMode,
            validator: (value) => value == null || value.trim().isEmpty
                ? l10n.playlistNameRequired
                : null,
          ),
          SizedBox(height: spacing.sm),
          AppTextField(
            fieldKey: _descriptionFieldKey,
            controller: _descriptionController,
            hintText: l10n.playlistDescriptionHint,
            enabled: !_isSubmitting,
            autovalidateMode: _autovalidateMode,
            maxLines: 3,
            minLines: 3,
          ),
          SizedBox(height: spacing.lg),
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
                  key: _submitKey,
                  label: l10n.commonSave,
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
    if (_isSubmitting) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!_hasAttemptedSubmit) {
      setState(() => _hasAttemptedSubmit = true);
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final playlist = await ref
          .read(playlistsApiProvider)
          .updatePlaylist(
            playlistId: widget.playlist.id,
            payload: UpdatePlaylistPayload(
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
            ),
          );
      if (!mounted) {
        return;
      }
      showToast(
        AppLocalizations.of(context).playlistUpdatedToast,
        tone: AppToastTone.success,
      );
      Navigator.of(context).pop(playlist);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      showToast(
        apiErrorMessage(error, fallback: l10n.playlistUpdateFailed, l10n: l10n),
        tone: AppToastTone.error,
      );
      setState(() => _isSubmitting = false);
    }
  }
}
