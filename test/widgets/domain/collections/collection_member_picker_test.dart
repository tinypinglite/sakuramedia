import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/add_clips_to_collection_dialog.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/add_moments_to_collection_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/logged_in_session_store.dart';
import '../../../support/preview_helpers.dart';
import '../../../support/test_api_bundle.dart';

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

  testWidgets('切片选择器回显成员并即时移出/加入', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-clips',
      body: _clipsPage(),
    );
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/clip-collections/10/clips/1',
      statusCode: 204,
    );
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/clip-collections/10/clips/1',
      statusCode: 204,
    );

    await _pumpAndOpen(tester, bundle, _OpenClipPickerHost());

    expect(find.byKey(const Key('add-clips-list')), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-clips-option-1')));
    await _pumpFrames(tester);
    expect(
      bundle.adapter.hitCount('DELETE', '/clip-collections/10/clips/1'),
      1,
    );

    await tester.tap(find.byKey(const Key('add-clips-option-1')));
    await _pumpFrames(tester);
    expect(bundle.adapter.hitCount('PUT', '/clip-collections/10/clips/1'), 1);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('时刻选择器切换类型后重载并即时移出/加入', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-points',
      body: _pointsPage(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-points',
      body: _pointsPage(),
    );
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/moment-collections/20/points/55',
      statusCode: 204,
    );
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/moment-collections/20/points/55',
      statusCode: 204,
    );

    await _pumpAndOpen(tester, bundle, _OpenMomentPickerHost());

    await tester.tap(find.byKey(const Key('add-moments-kind-jav')));
    await _pumpFrames(tester);
    expect(bundle.adapter.hitCount('GET', '/media-points'), 2);

    await tester.tap(find.byKey(const Key('add-moments-option-55')));
    await _pumpFrames(tester);
    expect(
      bundle.adapter.hitCount('DELETE', '/moment-collections/20/points/55'),
      1,
    );

    await tester.tap(find.byKey(const Key('add-moments-option-55')));
    await _pumpFrames(tester);
    expect(
      bundle.adapter.hitCount('PUT', '/moment-collections/20/points/55'),
      1,
    );
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}

class _OpenClipPickerHost extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => showAddClipsToCollectionDialog(
          context,
          collectionId: 10,
          memberClipIds: const <int>{1},
        ),
        child: const Text('打开切片选择器'),
      ),
    );
  }
}

class _OpenMomentPickerHost extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => showAddMomentsToCollectionDialog(
          context,
          collectionId: 20,
          memberPointIds: const <int>{55},
        ),
        child: const Text('打开时刻选择器'),
      ),
    );
  }
}

Future<void> _pumpAndOpen(
  WidgetTester tester,
  TestApiBundle bundle,
  Widget host,
) async {
  await pumpPreviewApp(
    tester,
    home: host,
    size: const Size(1100, 760),
    theme: buildSakuraDesktopThemeData(),
    platform: TargetPlatform.macOS,
    appPlatform: AppPlatform.desktop,
    bundle: bundle,
    settle: false,
  );
  await _pumpFrames(tester);
  await tester.tap(find.textContaining('打开'));
  await _pumpFrames(tester);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var index = 0; index < 12; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Map<String, dynamic> _clipsPage() {
  return <String, dynamic>{
    'items': <Map<String, dynamic>>[
      <String, dynamic>{
        'clip_id': 1,
        'media_id': 100,
        'movie_number': 'ABC-001',
        'start_offset_seconds': 0,
        'end_offset_seconds': 10,
        'title': 'Preview clip',
        'duration_seconds': 10,
        'file_size_bytes': 0,
        'cover_image': null,
        'stream_url': '',
        'created_at': null,
        'preview_frames': <dynamic>[],
        'collections': <dynamic>[],
      },
    ],
    'page': 1,
    'page_size': 24,
    'total': 1,
  };
}

Map<String, dynamic> _pointsPage() {
  return <String, dynamic>{
    'items': <Map<String, dynamic>>[
      <String, dynamic>{
        'point_id': 55,
        'media_id': 100,
        'movie_number': 'ABC-001',
        'thumbnail_id': 1,
        'offset_seconds': 10,
        'image': null,
        'created_at': null,
      },
    ],
    'page': 1,
    'page_size': 24,
    'total': 1,
  };
}
