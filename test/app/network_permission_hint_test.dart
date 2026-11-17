import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/network_permission_hint.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('network permission hints support Android, iOS, and macOS only', () {
    expect(supportsNetworkPermissionHint(TargetPlatform.android), isTrue);
    expect(supportsNetworkPermissionHint(TargetPlatform.iOS), isTrue);
    expect(supportsNetworkPermissionHint(TargetPlatform.macOS), isTrue);
    expect(supportsNetworkPermissionHint(TargetPlatform.windows), isFalse);
    expect(supportsNetworkPermissionHint(TargetPlatform.linux), isFalse);
  });

  testWidgets('a connection failure shows one permission hint', (tester) async {
    final failures = StreamController<ApiException>.broadcast();
    addTearDown(failures.close);
    await _pumpHost(
      tester,
      failures: failures.stream,
      platform: AppPlatform.desktop,
      targetPlatform: TargetPlatform.macOS,
      theme: sakuraDesktopThemeData,
    );

    failures
      ..add(_connectionFailure())
      ..add(_connectionFailure());

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.byKey(const Key('network-permission-hint')), findsOneWidget);
    expect(
      find.byKey(const Key('network-permission-hint-content')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('network-permission-hint-dismiss')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('network-permission-hint')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Windows does not show the permission hint', (tester) async {
    final failures = StreamController<ApiException>.broadcast();
    addTearDown(failures.close);
    await _pumpHost(
      tester,
      failures: failures.stream,
      platform: AppPlatform.desktop,
      targetPlatform: TargetPlatform.windows,
      theme: sakuraDesktopThemeData,
    );

    failures.add(_connectionFailure());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.byKey(const Key('network-permission-hint')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android shows the permission hint in a bottom drawer', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final failures = StreamController<ApiException>.broadcast();
    addTearDown(failures.close);
    await _pumpHost(
      tester,
      failures: failures.stream,
      platform: AppPlatform.mobile,
      targetPlatform: TargetPlatform.android,
      theme: sakuraMobileThemeData,
    );

    failures.add(_connectionFailure());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.byKey(const Key('network-permission-hint')), findsOneWidget);
    expect(find.byKey(const Key('app-bottom-drawer-content')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required Stream<ApiException> failures,
  required AppPlatform platform,
  required TargetPlatform targetPlatform,
  required ThemeData theme,
}) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      child: NetworkPermissionHintHost(
        platform: platform,
        navigatorKey: navigatorKey,
        failureStream: failures,
        targetPlatform: targetPlatform,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: theme,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Text('home')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ApiException _connectionFailure() {
  return const ApiException(
    message: 'Connection failed',
    transportFailureKind: ApiTransportFailureKind.connection,
  );
}
