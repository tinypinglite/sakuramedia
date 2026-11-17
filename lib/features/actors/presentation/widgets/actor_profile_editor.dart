import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';
import 'package:sakuramedia/features/shared/presentation/file_picker_with_bytes.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_mask.dart';
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
      title: AppLocalizations.of(context).actorProfileEditorTitle,
      body: _buildBody(context),
      submitKey: const Key('actor-profile-editor-submit'),
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
    );
  }

  Widget _buildBody(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
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
              label: l10n.actorProfileAliasLabel,
              hintText: l10n.actorProfileAliasHint,
              enabled: !_isSubmitting,
              maxLines: 1,
              validator: (value) => _validateDisplayName(value, l10n),
            ),
          ],
        ),
        SizedBox(height: spacing.xl),
        _buildSection(
          context,
          title: l10n.actorProfileBasicSectionTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSelectField<int>(
                label: l10n.actorProfileGenderLabel,
                value: _gender,
                items: [
                  DropdownMenuItem(value: 0, child: Text(l10n.commonUnknown)),
                  DropdownMenuItem(
                    value: 1,
                    child: Text(l10n.actorGenderFemaleOption),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text(l10n.actorGenderMaleOption),
                  ),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) => setState(() => _gender = value ?? 0),
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                fieldKey: const Key('actor-birthday-field'),
                controller: _birthdayController,
                label: l10n.actorBirthdayLabel,
                hintText: 'YYYY-MM-DD',
                enabled: !_isSubmitting,
                keyboardType: TextInputType.datetime,
                validator: (value) => _validateBirthday(value, l10n),
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                fieldKey: const Key('actor-height-field'),
                controller: _heightController,
                label: l10n.actorProfileHeightLabel,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                validator: (value) => _validatePositiveNumber(value, l10n),
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                fieldKey: const Key('actor-bust-field'),
                controller: _bustController,
                label: l10n.actorProfileBustLabel,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                validator: (value) => _validatePositiveNumber(value, l10n),
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                fieldKey: const Key('actor-waist-field'),
                controller: _waistController,
                label: l10n.actorProfileWaistLabel,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                validator: (value) => _validatePositiveNumber(value, l10n),
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                fieldKey: const Key('actor-hips-field'),
                controller: _hipsController,
                label: l10n.actorProfileHipsLabel,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.number,
                validator: (value) => _validatePositiveNumber(value, l10n),
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                fieldKey: const Key('actor-cup-field'),
                controller: _cupController,
                label: l10n.actorCupLabel,
                hintText: l10n.actorProfileCupHint,
                enabled: !_isSubmitting,
                textInputAction: TextInputAction.next,
                validator: (value) => _validateCup(value, l10n),
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                fieldKey: const Key('actor-birthplace-field'),
                controller: _birthplaceController,
                label: l10n.actorBirthplaceLabel,
                enabled: !_isSubmitting,
                validator: (value) => _validateShortText(value, l10n),
              ),
              SizedBox(height: spacing.md),
              AppTextField(
                fieldKey: const Key('actor-blood-type-field'),
                controller: _bloodTypeController,
                label: l10n.actorBloodTypeLabel,
                hintText: l10n.actorProfileBloodTypeHint,
                enabled: !_isSubmitting,
                validator: (value) => _validateBloodType(value, l10n),
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
    final l10n = AppLocalizations.of(context);
    final avatarSize = context.appComponentTokens.iconSize3xl;
    final image = _selectedImage == null
        ? ActorAvatar(
            imageUrl: _currentActor.summary.profileImage?.origin,
            size: avatarSize,
          )
        : ClipOval(
            child: AppImageMask.enabled
                ? SizedBox.square(
                    dimension: avatarSize,
                    child: ColoredBox(
                      color: AppImageMask.colorFor(
                        context,
                        AppImageMask.seedForBytes(_selectedImage!.bytes),
                      ),
                    ),
                  )
                : Image.memory(
                    _selectedImage!.bytes,
                    width: avatarSize,
                    height: avatarSize,
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
                    l10n.actorProfileCurrentAvatar,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      tone: AppTextTone.primary,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    l10n.actorProfileImageFormatHint,
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
              label: _selectedImage == null
                  ? l10n.actorProfilePickImage
                  : l10n.actorProfileChangeImage,
              icon: const Icon(Icons.image_outlined),
              size: AppButtonSize.small,
              onPressed: _isSubmitting ? null : _pickImage,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);
    try {
      final picked = await pickFileWithBytes(
        allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp'],
        unreadableMessage: l10n.actorProfileImageUnreadable,
        pickerUnavailableMessage: l10n.actorProfileImagePickerUnavailable,
        openFailureMessage: l10n.actorProfileImageOpenFailed,
        l10n: l10n,
      );
      if (picked == null || !mounted) {
        return;
      }
      setState(() {
        _selectedImage = picked;
        _errorMessage = null;
      });
    } on FilePickerWithBytesException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    final changes = _collectChanges();
    if (changes.isEmpty && _selectedImage == null) {
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
      _currentActor = current;
      if (mounted) {
        Navigator.of(context).pop(current);
      }
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _isSubmitting = false;
          _errorMessage = apiErrorMessage(
            error,
            fallback: l10n.actorProfileSaveFailed,
            l10n: l10n,
          );
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

  String? _validateDisplayName(String? value, AppLocalizations l10n) {
    final normalized = value?.trim() ?? '';
    return normalized.length > 255 ? l10n.actorProfileAliasTooLong : null;
  }

  String? _validateBirthday(String? value, AppLocalizations l10n) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    final date = DateTime.tryParse(normalized);
    if (date == null || normalized != _formatDate(date)) {
      return l10n.actorProfileBirthdayFormatInvalid;
    }
    if (date.isAfter(DateTime.now())) {
      return l10n.actorProfileBirthdayInFuture;
    }
    return null;
  }

  String? _validatePositiveNumber(String? value, AppLocalizations l10n) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(normalized);
    return parsed == null || parsed <= 0
        ? l10n.actorProfilePositiveIntegerRequired
        : null;
  }

  String? _validateCup(String? value, AppLocalizations l10n) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return RegExp(r'^[A-Z]$').hasMatch(normalized)
        ? null
        : l10n.actorProfileCupFormatInvalid;
  }

  String? _validateShortText(String? value, AppLocalizations l10n) {
    return (value?.trim().length ?? 0) > 255
        ? l10n.actorProfileTextTooLong
        : null;
  }

  String? _validateBloodType(String? value, AppLocalizations l10n) {
    final normalized = value?.trim().toUpperCase() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return const {'A', 'B', 'O', 'AB'}.contains(normalized)
        ? null
        : l10n.actorProfileBloodTypeFormatInvalid;
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
