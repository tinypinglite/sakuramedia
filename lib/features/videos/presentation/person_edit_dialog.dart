import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/videos/data/person_dto.dart';
import 'package:sakuramedia/features/videos/data/persons_api.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

const Map<int, String> _genderLabels = <int, String>{
  0: '未知',
  1: '女',
  2: '男',
};

/// 打开人物创建/编辑对话框。[existing] 为空表示创建。返回最新 [PersonDto]，取消返回 `null`。
Future<PersonDto?> showPersonEditDialog(
  BuildContext context, {
  PersonDto? existing,
}) {
  return showDialog<PersonDto>(
    context: context,
    builder: (dialogContext) => PersonEditDialog(existing: existing),
  );
}

class PersonEditDialog extends StatefulWidget {
  const PersonEditDialog({super.key, this.existing});

  final PersonDto? existing;

  @override
  State<PersonEditDialog> createState() => _PersonEditDialogState();
}

class _PersonEditDialogState extends State<PersonEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late int _gender;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _gender = widget.existing?.gender ?? 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AppDesktopDialog(
      width: 420,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? '编辑人物' : '新建人物',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s16,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            SizedBox(height: spacing.md),
            AppTextField(
              fieldKey: const Key('person-edit-name-field'),
              controller: _nameController,
              hintText: '人物姓名',
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入姓名' : null,
            ),
            SizedBox(height: spacing.md),
            Text(
              '性别',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
            SizedBox(height: spacing.sm),
            Wrap(
              spacing: spacing.sm,
              children: [
                for (final entry in _genderLabels.entries)
                  AppTextButton(
                    label: entry.value,
                    size: AppTextButtonSize.xSmall,
                    isSelected: _gender == entry.key,
                    onPressed: () => setState(() => _gender = entry.key),
                  ),
              ],
            ),
            SizedBox(height: spacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: '取消',
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: spacing.md),
                Expanded(
                  child: AppButton(
                    key: const Key('person-edit-submit-button'),
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
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    final personsApi = context.read<PersonsApi>();
    try {
      final PersonDto result;
      if (_isEditing) {
        result = await personsApi.updatePerson(
          personId: widget.existing!.id,
          payload: PersonUpdatePayload(
            name: _nameController.text.trim(),
            gender: _gender,
          ),
        );
      } else {
        result = await personsApi.createPerson(
          name: _nameController.text,
          gender: _gender,
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
