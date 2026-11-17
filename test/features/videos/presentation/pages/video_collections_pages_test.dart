import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_collections_page.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_collections_page.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('desktop collections loads once and renders the grid', (
    tester,
  ) async {
    _enqueueCollections(bundle, ids: <int>[10, 11]);

    await _pumpDesktop(tester, bundle);
    await _pumpFrames(tester);

    expect(find.byKey(const Key('video-collections-grid')), findsOneWidget);
    expect(bundle.adapter.hitCount('GET', '/video-collections'), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile collections filters by search and renders card keys', (
    tester,
  ) async {
    _enqueueCollections(
      bundle,
      ids: <int>[10, 11],
      names: <int, String>{10: 'Alpha', 11: 'Beta'},
    );

    await _pumpMobile(tester, bundle);
    await _pumpFrames(tester);

    expect(
      find.byKey(const Key('mobile-video-collections-grid')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-video-collection-card-10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-video-collection-card-11')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('mobile-video-collections-search-field')),
      'alpha',
    );
    await _pumpFrames(tester);

    expect(
      find.byKey(const Key('mobile-video-collection-card-10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mobile-video-collection-card-11')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('collection mutation refreshes the shared list', (tester) async {
    _enqueueCollections(bundle, ids: <int>[10]);

    await _pumpDesktop(tester, bundle);
    await _pumpFrames(tester);
    expect(bundle.adapter.hitCount('GET', '/video-collections'), 1);

    _enqueueCollections(bundle, ids: <int>[10]);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DesktopVideoCollectionsPage)),
    );
    container
        .read(videoMutationEventsProvider.notifier)
        .reportCollectionMembershipChanged(videoId: 10);
    await _pumpFrames(tester);

    expect(bundle.adapter.hitCount('GET', '/video-collections'), 2);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpDesktop(WidgetTester tester, TestApiBundle bundle) {
  return pumpPreviewApp(
    tester,
    home: const DesktopVideoCollectionsPage(),
    size: const Size(1100, 760),
    theme: buildSakuraDesktopThemeData(),
    platform: TargetPlatform.macOS,
    appPlatform: AppPlatform.desktop,
    bundle: bundle,
    settle: false,
  );
}

Future<void> _pumpMobile(WidgetTester tester, TestApiBundle bundle) {
  return pumpPreviewApp(
    tester,
    home: const MobileVideoCollectionsPage(),
    size: const Size(390, 844),
    theme: buildSakuraMobileThemeData(),
    platform: TargetPlatform.android,
    appPlatform: AppPlatform.mobile,
    bundle: bundle,
    settle: false,
  );
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _enqueueCollections(
  TestApiBundle bundle, {
  required List<int> ids,
  Map<int, String>? names,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/video-collections',
    body: ids
        .map(
          (id) => <String, dynamic>{
            'id': id,
            'name': names?[id] ?? 'Collection $id',
            'description': '',
            'item_count': 0,
            'cover_image': null,
            'created_at': null,
            'updated_at': null,
          },
        )
        .toList(),
  );
}
