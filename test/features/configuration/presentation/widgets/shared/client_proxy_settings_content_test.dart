import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/client_proxy_settings_content.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/pump_with_providers.dart';

void main() {
  testWidgets('客户端代理入口显示未设置并打开代理弹窗', (tester) async {
    await pumpWithProviders(
      tester,
      home: const SingleChildScrollView(child: ClientProxySettingsContent()),
      theme: sakuraDesktopThemeData,
      physicalSize: const Size(1100, 900),
    );

    expect(find.text('未设置'), findsOneWidget);

    await tester.tap(find.byKey(const Key('configuration-client-proxy-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('network-proxy-dialog')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
