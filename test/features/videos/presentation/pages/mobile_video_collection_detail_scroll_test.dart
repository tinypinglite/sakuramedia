import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_collection_detail_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
    _primeJson(
      bundle,
      path: '/video-collections/3',
      body: <String, dynamic>{
        'id': 3,
        'name': '城市夜行',
        'description': '周末连续播放。',
        'item_count': 24,
        'cover_image': null,
        'created_at': '2026-10-01T12:00:00',
        'updated_at': '2026-11-01T12:00:00',
      },
    );
    _primeJson(
      bundle,
      path: '/video-collections/3/videos',
      body: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          for (var index = 0; index < 24; index++)
            <String, dynamic>{
              'position': index,
              'video': <String, dynamic>{
                'id': index + 1,
                'title': '视频 ${index + 1}',
                'media_count': 1,
                'can_play': true,
                'cover_width': 720,
                'cover_height': 1080,
                'created_at': '2026-11-01T12:00:00',
                'updated_at': '2026-11-01T12:00:00',
              },
            },
        ],
        'page': 1,
        'page_size': 100,
        'total': 24,
      },
    );
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('mobile collection hero scrolls and the filter row pins', (
    tester,
  ) async {
    await pumpPreviewApp(
      tester,
      home: const AppMobileSubpageShell(
        title: '视频合集详情',
        defaultLocation: '/videos',
        currentPath: '/videos/collections/3',
        glassChrome: true,
        autoHideAppBar: false,
        child: MobileVideoCollectionDetailPage(collectionId: 3),
      ),
      wrap: (child) => child,
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.iOS,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
    );

    final hero = find.byKey(const Key('mobile-video-collection-hero'));
    final before = tester.getTopLeft(hero).dy;

    await tester.drag(
      find.byKey(const Key('mobile-video-collection-detail-scroll')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(hero).dy, lessThan(before));

    final filter = find.byKey(
      const Key('mobile-video-collection-sort-trigger'),
    );
    await tester.drag(
      find.byKey(const Key('mobile-video-collection-detail-scroll')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    final pinnedTop = tester.getTopLeft(filter).dy;

    await tester.drag(
      find.byKey(const Key('mobile-video-collection-detail-scroll')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(filter).dy, closeTo(pinnedTop, 0.1));
    expect(tester.takeException(), isNull);
  });
}

void _primeJson(
  TestApiBundle bundle, {
  required String path,
  required Object body,
}) {
  bundle.adapter.enqueueResponder(
    method: 'GET',
    path: path,
    responder: (RequestOptions _, dynamic __) async {
      return ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: const <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    },
  );
}
