import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/download_client_form.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';

void main() {
  const fields = <ProviderConfigFieldDto>[
    ProviderConfigFieldDto(
      key: 'endpoint',
      label: '服务地址',
      input: ProviderConfigFieldInput.text,
      required: true,
      multiline: false,
      readOnly: false,
      hint: null,
    ),
  ];

  test('editing with an unavailable provider omits provider_config', () {
    final nameController = TextEditingController(text: 'Downloader');
    final configController = ProviderConfigFormController(
      fields: fields,
      initialConfig: const <String, dynamic>{'endpoint': 'http://old'},
    );
    addTearDown(nameController.dispose);
    addTearDown(configController.dispose);

    final value = DownloadClientFormValue.fromControllers(
      nameController: nameController,
      providerConfigController: configController,
      isEditing: true,
      libraryId: 7,
      providerConfigAvailable: false,
    );

    expect(value.toUpdatePayload().toJson(), <String, dynamic>{
      'name': 'Downloader',
      'library_id': 7,
    });
  });

  test('editing with an available provider submits edited config', () {
    final nameController = TextEditingController(text: 'Downloader');
    final configController = ProviderConfigFormController(
      fields: fields,
      initialConfig: const <String, dynamic>{'endpoint': 'http://old'},
    );
    addTearDown(nameController.dispose);
    addTearDown(configController.dispose);
    configController.controllerFor('endpoint').text = 'http://new';

    final value = DownloadClientFormValue.fromControllers(
      nameController: nameController,
      providerConfigController: configController,
      isEditing: true,
      libraryId: 7,
    );

    expect(value.toUpdatePayload().toJson(), <String, dynamic>{
      'name': 'Downloader',
      'library_id': 7,
      'provider_config': <String, dynamic>{'endpoint': 'http://new'},
    });
  });
}
