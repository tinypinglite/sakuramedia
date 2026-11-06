import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

/// 视频合集创建/编辑的呈现形态：桌面弹窗 / 移动端底部抽屉。
enum VideoCollectionEditPresentation { dialog, bottomDrawer }

/// 打开视频合集创建/编辑对话框。[existing] 为空表示创建。返回最新 [VideoCollectionDto]。
Future<VideoCollectionDto?> showVideoCollectionDialog(
  BuildContext context, {
  VideoCollectionDto? existing,
  VideoCollectionEditPresentation presentation =
      VideoCollectionEditPresentation.dialog,
}) {
  switch (presentation) {
    case VideoCollectionEditPresentation.dialog:
      return showDialog<VideoCollectionDto>(
        context: context,
        builder: (dialogContext) =>
            CreateVideoCollectionDialog(existing: existing),
      );
    case VideoCollectionEditPresentation.bottomDrawer:
      return showAppBottomDrawer<VideoCollectionDto>(
        context: context,
        drawerKey: const Key('video-collection-edit-bottom-sheet'),
        maxHeightFactor: 0.62,
        builder: (sheetContext) => CreateVideoCollectionDialog(
          existing: existing,
          presentation: VideoCollectionEditPresentation.bottomDrawer,
        ),
      );
  }
}

class CreateVideoCollectionDialog extends ConsumerStatefulWidget {
  const CreateVideoCollectionDialog({
    super.key,
    this.existing,
    this.presentation = VideoCollectionEditPresentation.dialog,
  });

  final VideoCollectionDto? existing;
  final VideoCollectionEditPresentation presentation;

  @override
  ConsumerState<CreateVideoCollectionDialog> createState() =>
      _CreateVideoCollectionDialogState();
}

class _CreateVideoCollectionDialogState
    extends ConsumerState<CreateVideoCollectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.existing?.description ?? '',
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
    final l10n = AppLocalizations.of(context);
    if (widget.presentation == VideoCollectionEditPresentation.dialog) {
      return AppDesktopDialog(width: 420, child: _buildDesktopForm(context));
    }
    return AppBottomFormSheet(
      formKey: _formKey,
      title: _isEditing ? l10n.videoEditCollection : l10n.videoNewCollection,
      submitKey: const Key('video-collection-submit-button'),
      submitLabel: _isEditing ? l10n.commonSave : l10n.videoCreateCollection,
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
      body: _buildFieldsBody(context),
    );
  }

  Widget _buildFieldsBody(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          fieldKey: const Key('video-collection-name-field'),
          controller: _nameController,
          hintText: l10n.videoCollectionNameHint,
          enabled: !_isSubmitting,
          validator: (value) => value == null || value.trim().isEmpty
              ? l10n.videoCollectionNameRequired
              : null,
        ),
        SizedBox(height: spacing.sm),
        AppTextField(
          fieldKey: const Key('video-collection-description-field'),
          controller: _descriptionController,
          hintText: l10n.videoCollectionDescriptionHint,
          enabled: !_isSubmitting,
        ),
      ],
    );
  }

  Widget _buildDesktopForm(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? l10n.videoEditCollection : l10n.videoNewCollection,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.md),
          _buildFieldsBody(context),
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
                  key: const Key('video-collection-submit-button'),
                  label: _isEditing
                      ? l10n.commonSave
                      : l10n.videoCreateCollection,
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
    setState(() => _isSubmitting = true);
    final api = ref.read(videoCollectionsApiProvider);
    try {
      final VideoCollectionDto result;
      if (_isEditing) {
        result = await api.updateCollection(
          collectionId: widget.existing!.id,
          payload: VideoCollectionUpdatePayload(
            name: _nameController.text.trim(),
            description: _descriptionController.text,
          ),
        );
      } else {
        result = await api.createCollection(
          name: _nameController.text,
          description: _descriptionController.text,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } catch (error) {
      showToast(
        apiErrorMessage(
          error,
          fallback: _isEditing ? l10n.videoSaveFailed : l10n.videoCreateFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
