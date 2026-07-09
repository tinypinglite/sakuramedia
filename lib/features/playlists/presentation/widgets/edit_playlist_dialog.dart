import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/playlists/data/api/playlists_api.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

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
      return showDialog<PlaylistDto>(
        context: context,
        builder: (dialogContext) => EditPlaylistDialog(
          playlist: playlist,
          presentation: EditPlaylistDialogPresentation.dialog,
        ),
      );
    case EditPlaylistDialogPresentation.bottomDrawer:
      return showAppBottomDrawer<PlaylistDto>(
        context: context,
        drawerKey: const Key('mobile-playlist-edit-drawer'),
        heightFactor: 0.62,
        builder: (sheetContext) => EditPlaylistDialog(
          playlist: playlist,
          presentation: EditPlaylistDialogPresentation.bottomDrawer,
        ),
      );
  }
}

class EditPlaylistDialog extends StatefulWidget {
  const EditPlaylistDialog({
    super.key,
    required this.playlist,
    this.presentation = EditPlaylistDialogPresentation.dialog,
  });

  final PlaylistDto playlist;
  final EditPlaylistDialogPresentation presentation;

  @override
  State<EditPlaylistDialog> createState() => _EditPlaylistDialogState();
}

class _EditPlaylistDialogState extends State<EditPlaylistDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isSubmitting = false;
  bool _hasAttemptedSubmit = false;

  bool get _isDialog =>
      widget.presentation == EditPlaylistDialogPresentation.dialog;

  Key get _nameFieldKey => _isDialog
      ? const Key('configuration-playlist-name-field')
      : const Key('mobile-playlist-name-field');

  Key get _descriptionFieldKey => _isDialog
      ? const Key('configuration-playlist-description-field')
      : const Key('mobile-playlist-description-field');

  Key? get _submitKey =>
      _isDialog ? null : const Key('mobile-playlist-submit-button');

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
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(child: _buildFormContent(context)),
    );
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
            '编辑播放列表',
            style: resolveAppTextStyle(
              context,
              size: _isDialog ? AppTextSize.s18 : AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Text(
            '更新当前播放列表的名称和描述，保存后会立即生效。',
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
            hintText: '例如：稍后再看',
            enabled: !_isSubmitting,
            autovalidateMode: _autovalidateMode,
            validator: (value) => value == null || value.trim().isEmpty
                ? '请输入播放列表名称'
                : null,
          ),
          SizedBox(height: spacing.sm),
          AppTextField(
            fieldKey: _descriptionFieldKey,
            controller: _descriptionController,
            hintText: '描述可选',
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
                  label: '取消',
                  onPressed:
                      _isSubmitting ? null : () => Navigator.of(context).pop(),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: _submitKey,
                  label: '保存',
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
      final playlist = await context.read<PlaylistsApi>().updatePlaylist(
        playlistId: widget.playlist.id,
        payload: UpdatePlaylistPayload(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      showToast('播放列表已更新');
      Navigator.of(context).pop(playlist);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '更新播放列表失败'));
      setState(() => _isSubmitting = false);
    }
  }
}
