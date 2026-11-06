import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/moment_collections/data/dto/moment_collection_dto.dart';
import 'package:sakuramedia/features/moment_collections/presentation/providers/moment_collections_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 新建 / 编辑合集：桌面走居中弹窗，移动走底部抽屉（`auto` 读 `AppPlatformScope`）。
Future<MomentCollectionDto?> showMomentCollectionEditor(
  BuildContext context, {
  MomentCollectionDto? collection,
}) {
  return showAppAdaptiveModal<MomentCollectionDto>(
    context: context,
    drawerKey: const Key('moment-collection-editor-drawer'),
    desktopWidth: context.appComponentTokens.playlistDialogWidth,
    mobileMaxHeightFactor: 0.62,
    builder: (modalContext) => SingleChildScrollView(
      child: MomentCollectionEditor(
        collection: collection,
        onCancel: () => Navigator.of(modalContext).pop(),
        onSaved: (result) => Navigator.of(modalContext).pop(result),
      ),
    ),
  );
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
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing
                ? l10n.momentCollectionEditTitle
                : l10n.momentCollectionCreateTitle,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('moment-collection-name-field'),
            controller: _nameController,
            hintText: l10n.momentCollectionNameHint,
            enabled: !_isSubmitting,
            validator: (value) => value == null || value.trim().isEmpty
                ? l10n.momentCollectionNameRequired
                : null,
          ),
          SizedBox(height: spacing.sm),
          AppTextField(
            fieldKey: const Key('moment-collection-description-field'),
            controller: _descriptionController,
            hintText: l10n.momentCollectionDescriptionHint,
            enabled: !_isSubmitting,
          ),
          SizedBox(height: spacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.commonCancel,
                  onPressed: _isSubmitting ? null : widget.onCancel,
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: AppButton(
                  key: const Key('moment-collection-submit-button'),
                  label: _isEditing ? l10n.commonSave : l10n.momentCreateAction,
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
    final l10n = AppLocalizations.of(context);
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
      showToast(
        apiErrorMessage(
          error,
          fallback: _isEditing
              ? l10n.momentErrorSaveFailed
              : l10n.momentErrorCreateFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
