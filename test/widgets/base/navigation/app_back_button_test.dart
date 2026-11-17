import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/navigation/app_back_button.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('back button invokes its callback', (tester) async {
    var pressed = 0;
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Center(
          child: AppBackButton(
            key: const Key('test-back'),
            onPressed: () => pressed++,
          ),
        ),
      ),
      theme: sakuraDesktopThemeData,
    );

    await tester.tap(find.byKey(const Key('test-back')));

    expect(pressed, 1);
    expect(tester.takeException(), isNull);
  });
}
