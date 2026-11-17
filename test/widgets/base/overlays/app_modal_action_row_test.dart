import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_action_row.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('primary-only action row still submits', (tester) async {
    var submits = 0;
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: AppModalActionRow(
          showCancel: false,
          onSubmit: () => submits++,
          submitKey: const Key('modal-submit'),
          submitLabel: '保存',
        ),
      ),
      theme: sakuraThemeData,
      physicalSize: const Size(600, 400),
    );

    await tester.tap(find.byKey(const Key('modal-submit')));
    await tester.pump();

    expect(submits, 1);
  });
}
