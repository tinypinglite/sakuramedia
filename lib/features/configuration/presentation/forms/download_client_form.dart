import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

/// The local snapshot used to turn the editor into an API payload.
class DownloadClientFormValue {
  const DownloadClientFormValue({
    required this.name,
    required this.libraryId,
    required this.providerConfig,
    this.providerConfigAvailable = true,
  });

  factory DownloadClientFormValue.fromControllers({
    required TextEditingController nameController,
    required ProviderConfigFormController providerConfigController,
    required bool isEditing,
    required int? libraryId,
    bool providerConfigAvailable = true,
  }) {
    return DownloadClientFormValue(
      name: nameController.text.trim(),
      libraryId: libraryId,
      providerConfig: isEditing
          ? providerConfigController.toUpdateProviderConfig()
          : providerConfigController.toCreateProviderConfig(),
      providerConfigAvailable: providerConfigAvailable,
    );
  }

  final String name;
  final int? libraryId;
  final Map<String, dynamic> providerConfig;
  final bool providerConfigAvailable;

  CreateDownloadClientPayload toCreatePayload() {
    final selectedLibraryId = libraryId;
    if (selectedLibraryId == null) {
      throw StateError('download client requires a media library');
    }
    return CreateDownloadClientPayload(
      name: name,
      libraryId: selectedLibraryId,
      providerConfig: providerConfig,
    );
  }

  UpdateDownloadClientPayload toUpdatePayload() {
    return UpdateDownloadClientPayload(
      name: name,
      libraryId: libraryId,
      providerConfig: providerConfigAvailable ? providerConfig : null,
    );
  }
}

String? validateDownloadClientName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '请输入下载器名称';
  }
  return null;
}

/// Provider-neutral download client editor.
///
/// [libraries] is expected to contain only media libraries whose provider
/// advertises download support. The selected library determines the provider
/// configuration fields rendered below; this widget never exposes a provider
/// kind selector or provider-specific fields.
class DownloadClientFormFields extends StatelessWidget {
  const DownloadClientFormFields({
    super.key,
    required this.nameController,
    required this.libraries,
    required this.selectedLibraryId,
    required this.onLibraryChanged,
    required this.providerConfigController,
    required this.isEditing,
    this.enabled = true,
    this.autovalidateMode,
    this.nameFocusNode,
    this.libraryFocusNode,
    this.fieldSpacing,
    this.onSubmitted,
  });

  final TextEditingController nameController;
  final List<MediaLibraryDto> libraries;
  final int? selectedLibraryId;
  final ValueChanged<int?> onLibraryChanged;
  final ProviderConfigFormController providerConfigController;
  final bool isEditing;
  final bool enabled;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? nameFocusNode;
  final FocusNode? libraryFocusNode;
  final double? fieldSpacing;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final spacing = fieldSpacing ?? 16.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          fieldKey: const Key('download-client-name-field'),
          controller: nameController,
          focusNode: nameFocusNode,
          enabled: enabled,
          label: '名称',
          hintText: '给下载器起个名字',
          validator: validateDownloadClientName,
          autovalidateMode: autovalidateMode,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => libraryFocusNode?.requestFocus(),
        ),
        SizedBox(height: spacing),
        AppSelectField<int>(
          key: const Key('download-client-media-library-field'),
          value: selectedLibraryId,
          items: libraries
              .map(
                (library) => DropdownMenuItem<int>(
                  value: library.id,
                  child: Text(library.name),
                ),
              )
              .toList(growable: false),
          label: '目标媒体库',
          placeholder: libraries.isEmpty ? '暂无支持下载的媒体库' : '请选择目标媒体库',
          onChanged: enabled && libraries.isNotEmpty ? onLibraryChanged : null,
          validator: (value) => value == null ? '请选择目标媒体库' : null,
        ),
        if (providerConfigController.fields.isNotEmpty) ...[
          SizedBox(height: spacing),
          ProviderConfigFormFields(
            controller: providerConfigController,
            enabled: enabled,
            autovalidateMode: autovalidateMode,
            isEditing: isEditing,
            fieldSpacing: spacing,
          ),
        ],
      ],
    );
  }
}
