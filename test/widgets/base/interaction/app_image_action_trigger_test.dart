import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_trigger.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('long press callback takes priority over the context menu', (
    tester,
  ) async {
    var taps = 0;
    var longPresses = 0;
    var menus = 0;
    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Center(
          child: AppImageActionTrigger(
            key: const Key('image-trigger'),
            onTap: () => taps++,
            onLongPress: () => longPresses++,
            onRequestMenu: (_) => menus++,
            child: const SizedBox(width: 160, height: 90),
          ),
        ),
      ),
      theme: sakuraDesktopThemeData,
    );

    await tester.tap(find.byKey(const Key('image-trigger')));
    await tester.longPress(find.byKey(const Key('image-trigger')));

    expect(taps, 1);
    expect(longPresses, 1);
    expect(menus, 0);
    expect(tester.takeException(), isNull);
  });
}
