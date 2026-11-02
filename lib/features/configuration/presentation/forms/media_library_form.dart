import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

class MediaLibraryFormValue {
  const MediaLibraryFormValue({
    required this.name,
    required this.providerKey,
    required this.providerConfig,
    this.authSessionId,
  });

  factory MediaLibraryFormValue.fromControllers({
    required TextEditingController nameController,
    required String providerKey,
    required ProviderConfigFormController providerConfigController,
    required bool isEditing,
    Set<String> excludedProviderConfigKeys = const <String>{},
    String? authSessionId,
  }) {
    return MediaLibraryFormValue(
      name: nameController.text.trim(),
      providerKey: providerKey,
      providerConfig: isEditing
          ? providerConfigController.toUpdateProviderConfig(
              excludedKeys: excludedProviderConfigKeys,
            )
          : providerConfigController.toCreateProviderConfig(
              excludedKeys: excludedProviderConfigKeys,
            ),
      authSessionId: authSessionId,
    );
  }

  final String name;
  final String providerKey;
  final Map<String, dynamic> providerConfig;
  final String? authSessionId;

  CreateMediaLibraryPayload toCreatePayload() {
    return CreateMediaLibraryPayload(
      name: name,
      providerKey: providerKey,
      providerConfig: providerConfig,
      authSessionId: authSessionId,
    );
  }

  UpdateMediaLibraryPayload toUpdatePayload() {
    return UpdateMediaLibraryPayload(
      name: name,
      providerConfig: providerConfig,
      authSessionId: authSessionId,
    );
  }
}

String? validateMediaLibraryName(
  String? value, {
  required AppLocalizations l10n,
}) {
  if (value == null || value.trim().isEmpty) {
    return l10n.mediaLibraryNameRequired;
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
    final l10n = AppLocalizations.of(context);
    return AppTextField(
      fieldKey: nameFieldKey,
      controller: nameController,
      focusNode: nameFocusNode,
      enabled: enabled,
      label: l10n.mediaLibraryNameLabel,
      hintText: l10n.mediaLibraryNameHint,
      validator: (value) => validateMediaLibraryName(value, l10n: l10n),
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
    final l10n = AppLocalizations.of(context);
    return AppSelectField<String>(
      key: const Key('media-library-provider-field'),
      label: l10n.mediaLibraryProviderLabel,
      value: value,
      items: [
        for (final provider in providers)
          DropdownMenuItem<String>(
            value: provider.providerKey,
            child: Text(provider.displayName),
          ),
      ],
      onChanged: enabled ? onChanged : null,
      validator: (selected) =>
          selected == null ? l10n.mediaLibrarySelectProvider : null,
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
      AppLocalizations.of(
        context,
      ).mediaLibraryProviderUnavailableHint(providerKey),
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        tone: AppTextTone.error,
      ),
    );
  }
}
