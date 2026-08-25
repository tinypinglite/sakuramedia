import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

class MediaLibraryFormValue {
  const MediaLibraryFormValue({
    required this.name,
    required this.providerKey,
    required this.providerConfig,
  });

  factory MediaLibraryFormValue.fromControllers({
    required TextEditingController nameController,
    required String providerKey,
    required ProviderConfigFormController providerConfigController,
    required bool isEditing,
  }) {
    return MediaLibraryFormValue(
      name: nameController.text.trim(),
      providerKey: providerKey,
      providerConfig: isEditing
          ? providerConfigController.toUpdateProviderConfig()
          : providerConfigController.toCreateProviderConfig(),
    );
  }

  final String name;
  final String providerKey;
  final Map<String, dynamic> providerConfig;

  CreateMediaLibraryPayload toCreatePayload() {
    return CreateMediaLibraryPayload(
      name: name,
      providerKey: providerKey,
      providerConfig: providerConfig,
    );
  }

  UpdateMediaLibraryPayload toUpdatePayload() {
    return UpdateMediaLibraryPayload(
      name: name,
      providerConfig: providerConfig,
    );
  }
}

String? validateMediaLibraryName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '请输入媒体库名称';
  }
  return null;
}

/// 媒体库名称字段；Provider 配置字段由 [ProviderConfigFormFields] 驱动。
class MediaLibraryFormFields extends StatelessWidget {
  const MediaLibraryFormFields({
    super.key,
    required this.nameController,
    this.nameFocusNode,
    this.onNameSubmitted,
    this.enabled = true,
    this.autovalidateMode,
    this.nameFieldKey = const Key('media-library-name-field'),
  });

  final TextEditingController nameController;
  final FocusNode? nameFocusNode;
  final ValueChanged<String>? onNameSubmitted;
  final bool enabled;
  final AutovalidateMode? autovalidateMode;
  final Key nameFieldKey;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      fieldKey: nameFieldKey,
      controller: nameController,
      focusNode: nameFocusNode,
      enabled: enabled,
      label: '名称',
      hintText: '例如：Main Library',
      validator: validateMediaLibraryName,
      autovalidateMode: autovalidateMode,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: onNameSubmitted,
    );
  }
}

class MediaLibraryProviderSelectField extends StatelessWidget {
  const MediaLibraryProviderSelectField({
    super.key,
    required this.providers,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final List<MediaProviderDto> providers;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppSelectField<String>(
      key: const Key('media-library-provider-field'),
      label: '存储 Provider',
      value: value,
      items: [
        for (final provider in providers)
          DropdownMenuItem<String>(
            value: provider.providerKey,
            child: Text(provider.displayName),
          ),
      ],
      onChanged: enabled ? onChanged : null,
      validator: (selected) => selected == null ? '请选择存储 Provider' : null,
    );
  }
}

class MediaLibraryProviderUnavailableNotice extends StatelessWidget {
  const MediaLibraryProviderUnavailableNotice({
    super.key,
    required this.providerKey,
  });

  final String providerKey;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Provider「$providerKey」当前不可用，无法编辑其配置。可先修改名称；恢复插件后再编辑配置。',
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        tone: AppTextTone.error,
      ),
    );
  }
}
