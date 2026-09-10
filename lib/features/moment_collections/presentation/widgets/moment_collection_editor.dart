import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

enum MomentCollectionEditPresentation { dialog, bottomDrawer }

Future<MomentCollectionDto?> showMomentCollectionEditor(
  BuildContext context, {
  MomentCollectionDto? collection,
  required MomentCollectionEditPresentation presentation,
}) {
  return switch (presentation) {
    MomentCollectionEditPresentation.dialog => showDialog<MomentCollectionDto>(
      context: context,
      builder: (dialogContext) => AppDesktopDialog(
        width: dialogContext.appComponentTokens.playlistDialogWidth,
        child: MomentCollectionEditor(
          collection: collection,
          onCancel: () => Navigator.of(dialogContext).pop(),
          onSaved: (result) => Navigator.of(dialogContext).pop(result),
        ),
      ),
    ),
    MomentCollectionEditPresentation.bottomDrawer =>
      showAppBottomDrawer<MomentCollectionDto>(
        context: context,
        drawerKey: const Key('moment-collection-editor-drawer'),
        maxHeightFactor: 0.62,
        builder: (drawerContext) => SingleChildScrollView(
          child: MomentCollectionEditor(
            collection: collection,
            onCancel: () => Navigator.of(drawerContext).pop(),
            onSaved: (result) => Navigator.of(drawerContext).pop(result),
          ),
        ),
      ),
  };
}

class MomentCollectionEditor extends ConsumerStatefulWidget {
  const MomentCollectionEditor({
    super.key,
    required this.onCancel,
    required this.onSaved,
    this.collection,
  });

  final MomentCollectionDto? collection;
  final VoidCallback onCancel;
  final ValueChanged<MomentCollectionDto> onSaved;

  @override
  ConsumerState<MomentCollectionEditor> createState() =>
      _MomentCollectionEditorState();
}

class _MomentCollectionEditorState
    extends ConsumerState<MomentCollectionEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isSubmitting = false;

  bool get _isEditing => widget.collection != null;

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
  Widget build(BuildContext context) => _buildForm(context);

  Widget _buildForm(BuildContext context) {
    final spacing = context.appSpacing;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? '编辑时刻合集' : '新建时刻合集',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('moment-collection-name-field'),
            controller: _nameController,
            label: '合集名称',
            hintText: '例如：周末回看',
            enabled: !_isSubmitting,
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入合集名称' : null,
          ),
          SizedBox(height: spacing.sm),
          AppTextField(
            fieldKey: const Key('moment-collection-description-field'),
            controller: _descriptionController,
            label: '描述（可选）',
            hintText: '例如：按场景或时间整理',
            enabled: !_isSubmitting,
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '取消',
                  onPressed: _isSubmitting ? null : widget.onCancel,
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: const Key('moment-collection-submit-button'),
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
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(momentCollectionsApiProvider);
      final result = _isEditing
          ? await api.updateCollection(
              collectionId: widget.collection!.id,
              payload: UpdateMomentCollectionPayload(
                name: _nameController.text.trim(),
                description: _descriptionController.text.trim(),
              ),
            )
          : await api.createCollection(
              name: _nameController.text,
              description: _descriptionController.text,
            );
      if (mounted) widget.onSaved(result);
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: _isEditing ? '保存失败' : '创建失败'));
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
