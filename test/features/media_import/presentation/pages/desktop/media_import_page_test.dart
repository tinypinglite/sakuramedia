import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media_import/presentation/pages/desktop/media_import_page.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows unified import entry tabs', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
          theme: sakuraDesktopThemeData,
          home: const Scaffold(body: DesktopMediaImportPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-import-page')), findsOneWidget);
    expect(find.byKey(const Key('media-import-tab-jav')), findsOneWidget);
    expect(find.byKey(const Key('media-import-tab-video')), findsOneWidget);
    expect(find.byType(Text, skipOffstage: false), findsWidgets);
    expect(find.byKey(const Key('media-import-create-button')), findsOneWidget);
  });
}
