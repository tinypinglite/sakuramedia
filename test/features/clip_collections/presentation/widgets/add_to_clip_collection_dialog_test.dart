import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/add_to_clip_collection_dialog.dart';
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

  testWidgets(
    'clip membership dialog reflects current membership and toggles',
    (tester) async {
      _enqueueCollections(bundle);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media-clips/1',
        body: _clipDetailBody(
          collections: <Map<String, dynamic>>[
            <String, dynamic>{'id': 10, 'name': 'Alpha'},
          ],
        ),
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

      await pumpPreviewApp(
        tester,
        home: _OpenClipDialogHost(),
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
        find.byKey(const Key('add-to-clip-collection-dialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('add-to-clip-collection-list')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('add-to-clip-collection-option-10')),
      );
      await _pumpFrames(tester);
      expect(
        bundle.adapter.hitCount('DELETE', '/clip-collections/10/clips/1'),
        1,
      );

      await tester.tap(
        find.byKey(const Key('add-to-clip-collection-option-10')),
      );
      await _pumpFrames(tester);
      expect(bundle.adapter.hitCount('PUT', '/clip-collections/10/clips/1'), 1);
      expect(tester.takeException(), isNull);
    },
  );
}

class _OpenClipDialogHost extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => showAddToClipCollectionDialog(context, clipId: 1),
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
    path: '/clip-collections',
    body: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 10,
        'name': 'Alpha',
        'description': '',
        'clip_count': 2,
        'cover_image': null,
        'created_at': null,
        'updated_at': null,
      },
    ],
  );
}

Map<String, dynamic> _clipDetailBody({
  required List<Map<String, dynamic>> collections,
}) {
  return <String, dynamic>{
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
    'collections': collections,
  };
}
