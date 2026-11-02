import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/provider_login_validating_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('shows the provider name and switches to the slow hint', (
    tester,
  ) async {
    await _pumpCard(tester, locale: const Locale('zh'), providerName: '阿里云盘');

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('已检测到登录'), findsOneWidget);
    expect(find.text('正在验证 阿里云盘 账号'), findsOneWidget);
    expect(find.textContaining('网络较慢'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('正在验证 阿里云盘 账号'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('仍在验证 阿里云盘 账号，网络较慢时可能需要更久'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the English validation copy', (tester) async {
    await _pumpCard(tester, locale: const Locale('en'), providerName: '光鸭云盘');

    expect(find.text('Sign-in detected'), findsOneWidget);
    expect(find.text('Verifying your 光鸭云盘 account'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(
      find.text(
        'Still verifying your 光鸭云盘 account. This may take longer on a slow network.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  required Locale locale,
  required String providerName,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: sakuraMobileThemeData,
      locale: locale,
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      home: Scaffold(
        body: ProviderLoginValidatingCard(providerName: providerName),
      ),
    ),
  );
  await tester.pump();
}
