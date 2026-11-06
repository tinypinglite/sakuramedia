import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/add_to_moment_collection_dialog.dart';
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

  testWidgets('unsaved moment is created on first add and reused for remove', (
    tester,
  ) async {
    _enqueueCollections(bundle);
    _enqueueCreatedPoint(bundle);
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/moment-collections/20/points/55',
      statusCode: 204,
    );
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/moment-collections/20/points/55',
      statusCode: 204,
    );

    await _pumpAndOpen(tester, bundle);

    await tester.tap(find.byKey(const Key('add-to-moment-collection-20')));
    await _pumpFrames(tester);
    expect(bundle.adapter.hitCount('POST', '/media-points'), 1);
    expect(
      bundle.adapter.hitCount('PUT', '/moment-collections/20/points/55'),
      1,
    );

    await tester.tap(find.byKey(const Key('add-to-moment-collection-20')));
    await _pumpFrames(tester);
    expect(
      bundle.adapter.hitCount('DELETE', '/moment-collections/20/points/55'),
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed add cleans up the newly created point', (tester) async {
    _enqueueCollections(bundle);
    _enqueueCreatedPoint(bundle);
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/moment-collections/20/points/55',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'boom'},
    );
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/media-points/55',
      statusCode: 204,
    );

    await _pumpAndOpen(tester, bundle);

    await tester.tap(find.byKey(const Key('add-to-moment-collection-20')));
    await _pumpFrames(tester);
    expect(bundle.adapter.hitCount('POST', '/media-points'), 1);
    expect(bundle.adapter.hitCount('DELETE', '/media-points/55'), 1);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpAndOpen(WidgetTester tester, TestApiBundle bundle) async {
  await pumpPreviewApp(
    tester,
    home: _OpenMomentDialogHost(),
    size: const Size(1100, 760),
    theme: buildSakuraDesktopThemeData(),
    platform: TargetPlatform.macOS,
    appPlatform: AppPlatform.desktop,
    bundle: bundle,
    settle: false,
  );
  await _pumpFrames(tester);
  await tester.tap(find.text('打开加入合集'));
  await _pumpFrames(tester);
  expect(
    find.byKey(const Key('add-to-moment-collection-dialog')),
    findsOneWidget,
  );
}

class _OpenMomentDialogHost extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => showAddToMomentCollectionDialog(
          context,
          mediaId: 100,
          thumbnailId: 200,
        ),
        child: const Text('打开加入合集'),
      ),
    );
  }
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 12; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _enqueueCollections(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/moment-collections',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 20,
        'name': 'Alpha',
        'description': '',
        'point_count': 2,
        'cover_image': null,
        'created_at': null,
        'updated_at': null,
      },
    ],
  );
}

void _enqueueCreatedPoint(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'POST',
    path: '/media-points',
    body: <String, dynamic>{
      'point_id': 55,
      'media_id': 100,
      'thumbnail_id': 200,
      'offset_seconds': 0,
      'image': null,
      'created_at': null,
    },
  );
}
