import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/data/video_collections_api.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

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

class CreateVideoCollectionDialog extends StatefulWidget {
  const CreateVideoCollectionDialog({
    super.key,
    this.existing,
    this.presentation = VideoCollectionEditPresentation.dialog,
  });

  final VideoCollectionDto? existing;
  final VideoCollectionEditPresentation presentation;

  @override
  State<CreateVideoCollectionDialog> createState() =>
      _CreateVideoCollectionDialogState();
}

class _CreateVideoCollectionDialogState
    extends State<CreateVideoCollectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.existing?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.presentation == VideoCollectionEditPresentation.dialog) {
      return AppDesktopDialog(width: 420, child: _buildForm(context));
    }
    return SingleChildScrollView(child: _buildForm(context));
  }

  Widget _buildForm(BuildContext context) {
    final spacing = context.appSpacing;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? '编辑合集' : '新建合集',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('video-collection-name-field'),
            controller: _nameController,
            hintText: '合集名称',
            enabled: !_isSubmitting,
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入合集名称' : null,
          ),
          SizedBox(height: spacing.sm),
          AppTextField(
            fieldKey: const Key('video-collection-description-field'),
            controller: _descriptionController,
            hintText: '描述（可选）',
            enabled: !_isSubmitting,
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
                  key: const Key('video-collection-submit-button'),
                  label: _isEditing ? '保存' : '创建',
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
    setState(() => _isSubmitting = true);
    final api = context.read<VideoCollectionsApi>();
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
      showToast(apiErrorMessage(error, fallback: _isEditing ? '保存失败' : '创建失败'));
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
