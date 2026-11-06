import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_dismiss_controller.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('locked modal blocks system pop until unlocked', (tester) async {
    final dismissController = AppModalDismissController();
    addTearDown(dismissController.dispose);
    await pumpWithProviders(
      tester,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open-modal'),
              onPressed: () => showAppAdaptiveModal<void>(
                context: context,
                variant: AppAdaptiveModalVariant.dialog,
                dismissController: dismissController,
                builder: (_) => const SizedBox(
                  key: Key('modal-content'),
                  width: 240,
                  height: 140,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      theme: sakuraDesktopThemeData,
      physicalSize: const Size(1100, 760),
    );

    await tester.tap(find.byKey(const Key('open-modal')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('modal-content')), findsOneWidget);

    dismissController.setLocked(true);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('modal-content')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('modal-content')), findsOneWidget);

    dismissController.setLocked(false);
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('modal-content')), findsNothing);
    dismissAllToast();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked bottom drawer cannot be dragged away', (tester) async {
    final dismissController = AppModalDismissController();
    addTearDown(dismissController.dispose);
    await pumpWithProviders(
      tester,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open-drawer'),
              onPressed: () => showAppAdaptiveModal<void>(
                context: context,
                variant: AppAdaptiveModalVariant.drawer,
                dismissController: dismissController,
                modalKey: const Key('drawer-surface'),
                builder: (_) =>
                    const SizedBox(key: Key('drawer-content'), height: 140),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      theme: sakuraMobileThemeData,
      physicalSize: const Size(390, 844),
    );

    await tester.tap(find.byKey(const Key('open-drawer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drawer-content')), findsOneWidget);

    dismissController.setLocked(true);
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('app-bottom-drawer-handle')),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drawer-content')), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drawer-content')), findsOneWidget);

    dismissController.setLocked(false);
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('app-bottom-drawer-handle')),
      const Offset(0, 500),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drawer-content')), findsNothing);

    dismissAllToast();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
