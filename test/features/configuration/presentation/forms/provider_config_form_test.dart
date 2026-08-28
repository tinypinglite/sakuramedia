import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_config_form.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  final fields = <ProviderConfigFieldDto>[
    const ProviderConfigFieldDto(
      key: 'url',
      label: '服务地址',
      input: ProviderConfigFieldInput.text,
      required: true,
      multiline: false,
      readOnly: false,
      description: '服务地址的详细说明',
      hint: '例如 http://127.0.0.1:8080',
    ),
    const ProviderConfigFieldDto(
      key: 'password',
      label: '密码',
      input: ProviderConfigFieldInput.secret,
      required: true,
      multiline: false,
      readOnly: false,
      hint: null,
    ),
    const ProviderConfigFieldDto(
      key: 'account',
      label: '账号标识',
      input: ProviderConfigFieldInput.text,
      required: false,
      multiline: false,
      readOnly: true,
      hint: 'Provider 返回的只读标识',
    ),
  ];

  test(
    'controller has explicit create/edit secret serialization semantics',
    () {
      final controller = ProviderConfigFormController(
        fields: fields,
        initialConfig: const <String, dynamic>{'url': 'http://example.com'},
      );
      addTearDown(controller.dispose);

      controller.controllerFor('password').text = '';
      controller.controllerFor('account').text = 'account-from-server';
      expect(controller.toCreateProviderConfig(), <String, dynamic>{
        'url': 'http://example.com',
        'password': '',
      });
      expect(controller.toUpdateProviderConfig(), <String, dynamic>{
        'url': 'http://example.com',
      });

      controller.controllerFor('password').text = 'secret';
      expect(controller.toUpdateProviderConfig(), <String, dynamic>{
        'url': 'http://example.com',
        'password': 'secret',
      });
    },
  );

  testWidgets('create requires secret while edit allows an empty secret', (
    tester,
  ) async {
    final createController = ProviderConfigFormController(fields: fields);
    addTearDown(createController.dispose);
    final createFormKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: createFormKey,
              child: ProviderConfigFormFields(controller: createController),
            ),
          ),
        ),
      ),
    );
    expect(createFormKey.currentState!.validate(), isFalse);
    expect(
      find.byKey(const Key('provider-config-field-password')),
      findsOneWidget,
    );
    expect(find.text('服务地址的详细说明'), findsOneWidget);
    expect(
      find.byKey(const Key('provider-config-field-account')),
      findsNothing,
    );

    final editController = ProviderConfigFormController(fields: fields);
    addTearDown(editController.dispose);
    editController.controllerFor('url').text = 'http://example.com';
    final editFormKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: editFormKey,
              child: ProviderConfigFormFields(
                controller: editController,
                isEditing: true,
              ),
            ),
          ),
        ),
      ),
    );
    expect(editFormKey.currentState!.validate(), isTrue);
  });
}
