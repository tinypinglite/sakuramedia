import 'package:flutter/material.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';
import 'package:sakuramedia/features/shared/presentation/file_picker_with_bytes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_avatar.dart';

Future<ActorDetailDto?> showActorProfileEditor(
  BuildContext context, {
  required ActorDetailDto actor,
  required ActorsApi api,
}) {
  return showAppAdaptiveModal<ActorDetailDto>(
    context: context,
    modalKey: const Key('actor-profile-editor-modal'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    builder: (_) => ActorProfileEditor(actor: actor, api: api),
  );
}

class ActorProfileEditor extends StatefulWidget {
  const ActorProfileEditor({super.key, required this.actor, required this.api});

  final ActorDetailDto actor;
  final ActorsApi api;

  @override
  State<ActorProfileEditor> createState() => _ActorProfileEditorState();
}

class _ActorProfileEditorState extends State<ActorProfileEditor> {
  final _formKey = GlobalKey<FormState>();
  PickedFileWithBytes? _selectedImage;
  late final TextEditingController _displayNameController;
  late final TextEditingController _birthdayController;
  late final TextEditingController _heightController;
  late final TextEditingController _bustController;
  late final TextEditingController _waistController;
  late final TextEditingController _hipsController;
  late final TextEditingController _cupController;
  late final TextEditingController _birthplaceController;
  late final TextEditingController _bloodTypeController;

  late ActorDetailDto _currentActor;
  int _gender = 0;
  bool _removeLocalImage = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentActor = widget.actor;
    _gender = widget.actor.gender;
    _displayNameController = TextEditingController(
      text: widget.actor.displayNameOverride ?? '',
    );
    _birthdayController = TextEditingController(
      text: _formatDate(widget.actor.birthday),
    );
    _heightController = _numberController(widget.actor.heightCm);
    _bustController = _numberController(widget.actor.bustCm);
    _waistController = _numberController(widget.actor.waistCm);
    _hipsController = _numberController(widget.actor.hipsCm);
    _cupController = TextEditingController(text: widget.actor.cup ?? '');
    _birthplaceController = TextEditingController(
      text: widget.actor.birthplace ?? '',
    );
    _bloodTypeController = TextEditingController(
      text: widget.actor.bloodType ?? '',
    );
  }

  TextEditingController _numberController(int? value) {
    return TextEditingController(text: value?.toString() ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _birthdayController.dispose();
    _heightController.dispose();
    _bustController.dispose();
    _waistController.dispose();
    _hipsController.dispose();
    _cupController.dispose();
    _birthplaceController.dispose();
    _bloodTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomFormSheet(
      key: const Key('actor-profile-editor-form'),
      formKey: _formKey,
      title: '编辑女优资料',
      body: _buildBody(context),
      submitKey: const Key('actor-profile-editor-submit'),
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
    );
  }

  Widget _buildBody(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) ...[
          Text(
            _errorMessage!,
            key: const Key('actor-profile-editor-error'),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.error,
            ),
          ),
          SizedBox(height: spacing.md),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImageEditor(context),
            SizedBox(height: spacing.lg),
            AppTextField(
              fieldKey: const Key('actor-display-name-field'),
              controller: _displayNameController,
              label: '别名',
              hintText: '填写一个别名，会优先展示别名。',
              enabled: !_isSubmitting,
              maxLines: 1,
              validator: _validateDisplayName,
            ),
          ],
        ),
        SizedBox(height: spacing.xl),
        _buildSection(
          context,
          title: '基础资料',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSelectField<int>(
                label: '性别',
                value: _gender,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('未知')),
                  DropdownMenuItem(value: 1, child: Text('女性')),
                  DropdownMenuItem(value: 2, child: Text('男性')),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _gender = value ?? 0),
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                fieldKey: const Key('actor-birthday-field'),
                controller: _birthdayController,
                label: '生日',
                hintText: 'YYYY-MM-DD',
                enabled: !_isSubmitting,
                keyboardType: TextInputType.datetime,
                validator: _validateBirthday,
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                fieldKey: const Key('actor-height-field'),
                controller: _heightController,
                label: '身高（cm）',
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                validator: _validatePositiveNumber,
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                fieldKey: const Key('actor-bust-field'),
                controller: _bustController,
                label: '胸围（cm）',
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                validator: _validatePositiveNumber,
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                fieldKey: const Key('actor-waist-field'),
                controller: _waistController,
                label: '腰围（cm）',
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                validator: _validatePositiveNumber,
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                fieldKey: const Key('actor-hips-field'),
                controller: _hipsController,
                label: '臀围（cm）',
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                validator: _validatePositiveNumber,
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                fieldKey: const Key('actor-cup-field'),
                controller: _cupController,
                label: '罩杯',
                hintText: '例如 C、F',
                enabled: !_isSubmitting,
                textInputAction: TextInputAction.next,
                validator: _validateCup,
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                fieldKey: const Key('actor-birthplace-field'),
                controller: _birthplaceController,
                label: '出生地',
                enabled: !_isSubmitting,
                validator: _validateShortText,
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                fieldKey: const Key('actor-blood-type-field'),
                controller: _bloodTypeController,
                label: '血型',
                hintText: 'A、B、O 或 AB',
                enabled: !_isSubmitting,
                validator: _validateBloodType,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.medium,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.md),
        child,
      ],
    );
  }

  Widget _buildImageEditor(BuildContext context) {
    final spacing = context.appSpacing;
    final image = _selectedImage == null
        ? ActorAvatar(
            imageUrl: _currentActor.summary.profileImage?.bestAvailableUrl,
            size: context.appComponentTokens.iconSize3xl,
          )
        : ClipOval(
            child: Image.memory(
              _selectedImage!.bytes,
              width: context.appComponentTokens.iconSize3xl,
              height: context.appComponentTokens.iconSize3xl,
              fit: BoxFit.cover,
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            image,
            SizedBox(width: spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前头像',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      tone: AppTextTone.primary,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    '支持 JPEG、PNG、WebP，保存时上传',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              key: const Key('actor-profile-image-pick'),
              label: _selectedImage == null ? '选择图片' : '更换图片',
              icon: const Icon(Icons.image_outlined),
              size: AppButtonSize.small,
              onPressed: _isSubmitting ? null : _pickImage,
            ),
            if (_currentActor.hasProfileImageOverride) ...[
              SizedBox(width: spacing.sm),
              AppButton(
                key: const Key('actor-profile-image-clear'),
                label: _removeLocalImage ? '取消恢复' : '恢复来源头像',
                size: AppButtonSize.small,
                onPressed: _isSubmitting ? null : _toggleImageReset,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      final picked = await pickFileWithBytes(
        allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
        unreadableMessage: '无法读取所选图片，请换一张再试',
        pickerUnavailableMessage: '图片选择器尚未加载，请完整重启应用后再试',
        openFailureMessage: '打开图片选择器失败，请稍后再试',
      );
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _selectedImage = picked;
        _removeLocalImage = false;
        _errorMessage = null;
      });
    } on FilePickerWithBytesException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    }
  }

  void _toggleImageReset() {
    setState(() {
      _removeLocalImage = !_removeLocalImage;
      _selectedImage = null;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    final changes = _collectChanges();
    if (changes.isEmpty && _selectedImage == null && !_removeLocalImage) {
      Navigator.of(context).pop(_currentActor);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      var current = _currentActor;
      if (changes.isNotEmpty) {
        current = await widget.api.updateActor(
          actorId: current.summary.id,
          expectedRevision: current.mutationRevision,
          changes: changes,
        );
      }
      if (_selectedImage != null) {
        current = await widget.api.uploadActorProfileImage(
          actorId: current.summary.id,
          expectedRevision: current.mutationRevision,
          bytes: _selectedImage!.bytes,
          fileName: _selectedImage!.fileName,
        );
      }
      if (_removeLocalImage) {
        current = await widget.api.clearActorProfileImage(
          actorId: current.summary.id,
          expectedRevision: current.mutationRevision,
        );
      }
      _currentActor = current;
      if (mounted) {
        Navigator.of(context).pop(current);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = apiErrorMessage(error, fallback: '保存女优资料失败，请稍后重试');
        });
      }
    }
  }

  Map<String, dynamic> _collectChanges() {
    final changes = <String, dynamic>{};
    final displayName = _nullableText(_displayNameController.text);
    if (displayName != _currentActor.displayNameOverride) {
      changes['display_name_override'] = displayName;
    }
    if (_gender != _currentActor.gender) {
      changes['gender'] = _gender;
    }

    final birthday = _nullableText(_birthdayController.text);
    final currentBirthday = _currentActor.birthday == null
        ? null
        : _formatDate(_currentActor.birthday);
    if (birthday != currentBirthday) {
      changes['birthday'] = birthday;
    }
    _addNumberChange(
      changes,
      'height_cm',
      _heightController,
      _currentActor.heightCm,
    );
    _addNumberChange(changes, 'bust_cm', _bustController, _currentActor.bustCm);
    _addNumberChange(
      changes,
      'waist_cm',
      _waistController,
      _currentActor.waistCm,
    );
    _addNumberChange(changes, 'hips_cm', _hipsController, _currentActor.hipsCm);

    final cup = _nullableText(_cupController.text)?.toUpperCase();
    if (cup != _currentActor.cup) {
      changes['cup'] = cup;
    }
    _addTextChange(
      changes,
      'birthplace',
      _birthplaceController,
      _currentActor.birthplace,
    );
    final bloodType = _nullableText(_bloodTypeController.text)?.toUpperCase();
    final currentBloodType = _currentActor.bloodType?.trim().toUpperCase();
    if (bloodType != currentBloodType) {
      changes['blood_type'] = bloodType;
    }
    return changes;
  }

  void _addNumberChange(
    Map<String, dynamic> changes,
    String key,
    TextEditingController controller,
    int? current,
  ) {
    final value = _nullableText(controller.text);
    final parsed = value == null ? null : int.parse(value);
    if (parsed != current) {
      changes[key] = parsed;
    }
  }

  void _addTextChange(
    Map<String, dynamic> changes,
    String key,
    TextEditingController controller,
    String? current,
  ) {
    final value = _nullableText(controller.text);
    if (value != current) {
      changes[key] = value;
    }
  }

  String? _validateDisplayName(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.length > 255 ? '别名不能超过 255 个字符' : null;
  }

  String? _validateBirthday(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    final date = DateTime.tryParse(normalized);
    if (date == null || normalized != _formatDate(date)) {
      return '请输入 YYYY-MM-DD 格式的日期';
    }
    if (date.isAfter(DateTime.now())) {
      return '生日不能晚于今天';
    }
    return null;
  }

  String? _validatePositiveNumber(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(normalized);
    return parsed == null || parsed <= 0 ? '请输入正整数' : null;
  }

  String? _validateCup(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return RegExp(r'^[A-Z]$').hasMatch(normalized) ? null : '请输入 1 个大写英文字母';
  }

  String? _validateShortText(String? value) {
    return (value?.trim().length ?? 0) > 255 ? '内容不能超过 255 个字符' : null;
  }

  String? _validateBloodType(String? value) {
    final normalized = value?.trim().toUpperCase() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return const {'A', 'B', 'O', 'AB'}.contains(normalized)
        ? null
        : '请输入 A、B、O 或 AB';
  }

  static String? _nullableText(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  static String _formatDate(DateTime? value) {
    if (value == null) {
      return '';
    }
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
