import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/plugins/presentation/widgets/plugin_restart_notice_dialog.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/pump_with_providers.dart';

void main() {
  testWidgets('desktop restart notice requires acknowledgement', (
    tester,
  ) async {
    await _openRestartNotice(tester);
    await _expectRestartNoticeFlow(tester);
  });

  testWidgets('mobile restart notice requires acknowledgement', (tester) async {
    await _openRestartNotice(tester, mobile: true);
    await _expectRestartNoticeFlow(tester);
  });
}

Future<void> _openRestartNotice(
  WidgetTester tester, {
  bool mobile = false,
}) async {
  await pumpWithProviders(
    tester,
    theme: mobile
        ? buildSakuraMobileThemeData()
        : buildSakuraDesktopThemeData(),
    physicalSize: mobile ? const Size(390, 844) : const Size(1100, 800),
    wrap: mobile
        ? (child) =>
              AppPlatformScope(platform: AppPlatform.mobile, child: child)
        : null,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            key: const Key('open-plugin-restart-notice'),
            onPressed: () => showPluginRestartNoticeDialog(
              context,
              action: PluginRestartNoticeAction.upgraded,
              pluginName: '115 provider',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-plugin-restart-notice')));
  await tester.pumpAndSettle();
}

Future<void> _expectRestartNoticeFlow(WidgetTester tester) async {
  expect(find.byKey(const Key('plugin-restart-notice-dialog')), findsOneWidget);

  await tester.tapAt(const Offset(5, 5));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('plugin-restart-notice-dialog')), findsOneWidget);

  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('plugin-restart-notice-dialog')), findsOneWidget);

  await tester.tap(
    find.byKey(const Key('plugin-restart-notice-confirm-button')),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('plugin-restart-notice-dialog')), findsOneWidget);

  await tester.tap(find.byKey(const Key('plugin-restart-notice-checkbox')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const Key('plugin-restart-notice-confirm-button')),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('plugin-restart-notice-dialog')), findsNothing);
}
