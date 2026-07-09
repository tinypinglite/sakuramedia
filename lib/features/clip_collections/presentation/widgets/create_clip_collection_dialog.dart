import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/data/api/clip_collections_api.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

/// 合集新建/编辑的呈现形态：桌面弹窗 / 移动端底部抽屉。
enum ClipCollectionEditPresentation { dialog, bottomDrawer }

/// 新建切片合集，成功返回新建的合集。
Future<ClipCollectionDto?> showCreateClipCollectionDialog(
  BuildContext context, {
  ClipCollectionEditPresentation presentation =
      ClipCollectionEditPresentation.dialog,
}) {
  return _showClipCollectionEditDialog(context, presentation: presentation);
}

/// 编辑已有合集（名称 / 描述），成功返回更新后的合集。
Future<ClipCollectionDto?> showEditClipCollectionDialog(
  BuildContext context, {
  required ClipCollectionDto collection,
  ClipCollectionEditPresentation presentation =
      ClipCollectionEditPresentation.dialog,
}) {
  return _showClipCollectionEditDialog(
    context,
    collection: collection,
    presentation: presentation,
  );
}

Future<ClipCollectionDto?> _showClipCollectionEditDialog(
  BuildContext context, {
  ClipCollectionDto? collection,
  required ClipCollectionEditPresentation presentation,
}) {
  switch (presentation) {
    case ClipCollectionEditPresentation.dialog:
      return showDialog<ClipCollectionDto>(
        context: context,
        builder:
            (dialogContext) => ClipCollectionEditDialog(collection: collection),
      );
    case ClipCollectionEditPresentation.bottomDrawer:
      return showAppBottomDrawer<ClipCollectionDto>(
        context: context,
        drawerKey: const Key('clip-collection-edit-bottom-sheet'),
        maxHeightFactor: 0.62,
        builder:
            (sheetContext) => ClipCollectionEditDialog(
              collection: collection,
              presentation: ClipCollectionEditPresentation.bottomDrawer,
            ),
      );
  }
}

/// 合集新建/编辑共用对话框：`collection` 为空表示新建。
class ClipCollectionEditDialog extends StatefulWidget {
  const ClipCollectionEditDialog({
    super.key,
    this.collection,
    this.presentation = ClipCollectionEditPresentation.dialog,
  });

  final ClipCollectionDto? collection;
  final ClipCollectionEditPresentation presentation;

  bool get isEditing => collection != null;

  @override
  State<ClipCollectionEditDialog> createState() =>
      _ClipCollectionEditDialogState();
}

class _ClipCollectionEditDialogState extends State<ClipCollectionEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.collection?.name ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.collection?.description ?? '',
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
    if (widget.presentation == ClipCollectionEditPresentation.dialog) {
      return AppDesktopDialog(
        width: context.appComponentTokens.playlistDialogWidth,
        child: _buildForm(context),
      );
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
            widget.isEditing ? '编辑合集' : '新建合集',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('clip-collection-name-field'),
            controller: _nameController,
            hintText: '例如：年度精选',
            enabled: !_isSubmitting,
            validator:
                (value) =>
                    value == null || value.trim().isEmpty ? '请输入合集名称' : null,
          ),
          SizedBox(height: spacing.sm),
          AppTextField(
            fieldKey: const Key('clip-collection-description-field'),
            controller: _descriptionController,
            hintText: '描述可选',
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
                  key: const Key('clip-collection-submit-button'),
                  label: widget.isEditing ? '保存' : '创建',
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
    final api = context.read<ClipCollectionsApi>();
    try {
      final ClipCollectionDto result;
      if (widget.isEditing) {
        result = await api.updateCollection(
          collectionId: widget.collection!.id,
          payload: UpdateClipCollectionPayload(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
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
        apiErrorMessage(error, fallback: widget.isEditing ? '保存失败' : '创建合集失败'),
      );
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
