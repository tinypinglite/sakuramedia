import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/configuration/presentation/pages/shared/media_tags_page.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';

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
  });

  testWidgets('desktop page lists tags and opens the shared editor', (
    tester,
  ) async {
    _enqueueTags(bundle);

    await pumpPreviewApp(
      tester,
      home: const MediaTagsPage(mobile: false),
      size: const Size(1100, 900),
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
      bundle: bundle,
      wrap: (child) => SingleChildScrollView(child: child),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-tag-rule-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('media-tag-create-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('media-tag-name-field')), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const Key('media-tag-name-field'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('media-tag-edit-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('media-tag-name-field')), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const Key('media-tag-name-field'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('media-tag-delete-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('media-tag-delete-confirm-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('media-tag-delete-cancel-1')));
    await tester.pumpAndSettle();
    expect(bundle.adapter.hitCount('GET', '/media-tags'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile page lists tags and opens the shared editor', (
    tester,
  ) async {
    _enqueueTags(bundle);

    await pumpPreviewApp(
      tester,
      home: const MediaTagsPage(mobile: true),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-settings-media-tags')), findsOneWidget);
    expect(find.byKey(const Key('mobile-media-tag-rule-1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mobile-media-tag-create-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('media-tag-name-field')), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const Key('media-tag-name-field'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-media-tag-more-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mobile-media-tag-actions-1')), findsOneWidget);
    expect(find.byKey(const Key('mobile-media-tag-edit-1')), findsOneWidget);
    expect(find.byKey(const Key('mobile-media-tag-delete-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-media-tag-edit-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('media-tag-name-field')), findsOneWidget);
    Navigator.of(
      tester.element(find.byKey(const Key('media-tag-name-field'))),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mobile-media-tag-more-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mobile-media-tag-delete-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('mobile-media-tag-delete-confirm-1')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('mobile-media-tag-delete-cancel-1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

void _enqueueTags(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/media-tags',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'name': '4K',
        'include_terms': <String>['4k', '2160p'],
        'exclude_terms': <String>['cam'],
        'enabled': true,
        'media_count': 12,
      },
    ],
  );
}
