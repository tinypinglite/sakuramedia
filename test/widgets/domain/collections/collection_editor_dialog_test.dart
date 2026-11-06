import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/widgets/create_clip_collection_dialog.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/edit_playlist_dialog.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/create_video_collection_dialog.dart';
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

  testWidgets('桌面合集创建弹窗提交名称', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/clip-collections',
      body: _clipCollectionBody(id: 30, name: 'My clips'),
    );
    ClipCollectionDto? result;

    await _pumpAndOpen(
      tester,
      bundle,
      _Host(
        label: '打开创建合集',
        onPressed: (context) async {
          result = await showCreateClipCollectionDialog(context);
        },
      ),
    );
    await tester.enterText(
      find.byKey(const Key('clip-collection-name-field')),
      'My clips',
    );
    await tester.tap(find.byKey(const Key('clip-collection-submit-button')));
    await _pumpFrames(tester);

    expect(result?.id, 30);
    expect(bundle.adapter.requests.single.method, 'POST');
    expect(bundle.adapter.requests.single.path, '/clip-collections');
    expect(bundle.adapter.requests.single.body['name'], 'My clips');
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('播放列表编辑弹窗回填并提交', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/playlists/8',
      body: _playlistBody(id: 8, name: 'Updated'),
    );
    PlaylistDto? result;
    final playlist = PlaylistDto.fromJson(_playlistBody(id: 8, name: 'Old'));

    await _pumpAndOpen(
      tester,
      bundle,
      _Host(
        label: '打开编辑播放列表',
        onPressed: (context) async {
          result = await showEditPlaylistDialog(context, playlist: playlist);
        },
      ),
    );
    expect(find.text('Old'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('playlist-edit-name-field')),
      'Updated',
    );
    await tester.tap(find.byKey(const Key('playlist-edit-submit-button')));
    await _pumpFrames(tester);

    expect(result?.name, 'Updated');
    expect(bundle.adapter.requests.single.method, 'PATCH');
    expect(bundle.adapter.requests.single.path, '/playlists/8');
    expect(bundle.adapter.requests.single.body['name'], 'Updated');
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('移动视频合集 bottom form sheet 提交名称', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/video-collections',
      body: _videoCollectionBody(id: 40, name: 'New videos'),
    );
    VideoCollectionDto? result;

    await _pumpAndOpen(
      tester,
      bundle,
      _Host(
        label: '打开视频合集',
        onPressed: (context) async {
          result = await showVideoCollectionDialog(
            context,
            presentation: VideoCollectionEditPresentation.bottomDrawer,
          );
        },
      ),
    );
    await tester.enterText(
      find.byKey(const Key('video-collection-name-field')),
      'New videos',
    );
    await tester.tap(find.byKey(const Key('video-collection-submit-button')));
    await _pumpFrames(tester);

    expect(result?.id, 40);
    expect(bundle.adapter.requests.single.method, 'POST');
    expect(bundle.adapter.requests.single.path, '/video-collections');
    expect(bundle.adapter.requests.single.body['name'], 'New videos');
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}

class _Host extends StatelessWidget {
  const _Host({required this.label, required this.onPressed});

  final String label;
  final Future<void> Function(BuildContext context) onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () => onPressed(context),
        child: Text(label),
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

Map<String, dynamic> _clipCollectionBody({
  required int id,
  required String name,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'description': '',
    'clip_count': 0,
    'cover_image': null,
    'created_at': null,
    'updated_at': null,
  };
}

Map<String, dynamic> _playlistBody({required int id, required String name}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'kind': 'custom',
    'description': '',
    'is_system': false,
    'is_mutable': true,
    'is_deletable': true,
    'movie_count': 0,
    'created_at': null,
    'updated_at': null,
  };
}

Map<String, dynamic> _videoCollectionBody({
  required int id,
  required String name,
}) {
  return <String, dynamic>{
    'id': id,
    'name': name,
    'description': '',
    'item_count': 0,
    'cover_image': null,
    'created_at': null,
    'updated_at': null,
  };
}
