import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/media_library_form.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';

void main() {
  test('form value serializes provider key and config for create/edit', () {
    final nameController = TextEditingController(text: 'Main');
    final configController = ProviderConfigFormController(
      fields: const <ProviderConfigFieldDto>[
        ProviderConfigFieldDto(
          key: 'url',
          label: 'URL',
          input: ProviderConfigFieldInput.text,
          required: true,
          multiline: false,
          readOnly: false,
          hint: null,
        ),
        ProviderConfigFieldDto(
          key: 'token',
          label: 'Token',
          input: ProviderConfigFieldInput.secret,
          required: false,
          multiline: false,
          readOnly: false,
          hint: null,
        ),
      ],
      initialConfig: const <String, dynamic>{'url': 'https://example.com'},
    );
    addTearDown(nameController.dispose);
    addTearDown(configController.dispose);

    configController.controllerFor('token').text = '';
    final value = MediaLibraryFormValue.fromControllers(
      nameController: nameController,
      providerKey: 'demo',
      providerConfigController: configController,
      isEditing: true,
    );

    expect(value.toUpdatePayload().toJson(), <String, dynamic>{
      'name': 'Main',
      'provider_config': <String, dynamic>{'url': 'https://example.com'},
    });
  });
}
