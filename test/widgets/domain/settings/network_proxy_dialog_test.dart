import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/network_proxy_store.dart';
import 'package:sakuramedia/app/providers/network_proxy_providers.dart';
import 'package:sakuramedia/core/network/network_proxy.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/domain/settings/network_proxy_dialog.dart';

import '../../../support/logged_in_session_store.dart';
import '../../../support/preview_helpers.dart';
import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
    NetworkProxyRuntime.update(null);
  });

  List<Override> proxyOverrides(NetworkProxyStore store) => <Override>[
    networkProxyStoreProvider.overrideWithValue(store),
  ];

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open-network-proxy')));
    await tester.pumpAndSettle();
  }

  testWidgets('desktop dialog saves, rejects invalid input and clears', (
    tester,
  ) async {
    const initial = NetworkProxyConfig(host: '127.0.0.1', port: 7890);
    final store = InMemoryNetworkProxyStore(initial);

    await pumpPreviewApp(
      tester,
      home: const _OpenProxyHost(),
      size: const Size(1100, 800),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
      extraOverrides: proxyOverrides(store),
    );
    await openDialog(tester);

    expect(find.byKey(const Key('network-proxy-dialog')), findsOneWidget);
    expect(_fieldText(tester), '127.0.0.1:7890');

    await tester.enterText(
      find.byKey(const Key('network-proxy-field')),
      'socks5://127.0.0.1:7890',
    );
    await tester.tap(find.byKey(const Key('network-proxy-save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('network-proxy-dialog')), findsOneWidget);
    expect(store.read(), initial);

    await tester.enterText(
      find.byKey(const Key('network-proxy-field')),
      '192.168.2.5:7890',
    );
    await tester.tap(find.byKey(const Key('network-proxy-save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('network-proxy-dialog')), findsNothing);
    expect(
      store.read(),
      const NetworkProxyConfig(host: '192.168.2.5', port: 7890),
    );

    await openDialog(tester);
    expect(_fieldText(tester), '192.168.2.5:7890');
    await tester.enterText(find.byKey(const Key('network-proxy-field')), '');
    await tester.tap(find.byKey(const Key('network-proxy-save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('network-proxy-dialog')), findsNothing);
    expect(store.read(), isNull);
  });

  testWidgets('mobile opens the proxy drawer and saves', (tester) async {
    final store = InMemoryNetworkProxyStore();

    await pumpPreviewApp(
      tester,
      home: const _OpenProxyHost(),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
      extraOverrides: proxyOverrides(store),
    );
    await openDialog(tester);

    expect(find.byKey(const Key('network-proxy-sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('network-proxy-field')),
      'http://[::1]:7890',
    );
    await tester.tap(find.byKey(const Key('network-proxy-save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('network-proxy-sheet')), findsNothing);
    expect(store.read(), const NetworkProxyConfig(host: '::1', port: 7890));
  });
}

String _fieldText(WidgetTester tester) {
  final editable = tester.widget<EditableText>(
    find.descendant(
      of: find.byKey(const Key('network-proxy-field')),
      matching: find.byType(EditableText),
    ),
  );
  return editable.controller.text;
}

class _OpenProxyHost extends StatelessWidget {
  const _OpenProxyHost();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppButton(
        key: const Key('open-network-proxy'),
        label: 'open',
        onPressed: () => unawaited(showNetworkProxyDialog(context)),
      ),
    );
  }
}
