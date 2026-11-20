import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/pornbox_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/preview_helpers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sessionStore = await buildLoggedInSessionStore();
    bundle = await createTestApiBundle(sessionStore);
    _enqueueVideos(bundle);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('PornBox filter row pins while the video grid scrolls', (
    tester,
  ) async {
    await pumpPreviewApp(
      tester,
      home: const MobilePornboxPage(),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.iOS,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
      wrap: (child) => Scaffold(body: child),
    );

    final filter = find.byKey(const Key('mobile-pornbox-filter-button'));
    final initialTop = tester.getTopLeft(filter).dy;
    final scrollView = find.byType(CustomScrollView).first;

    await tester.drag(scrollView, const Offset(0, -520));
    await tester.pumpAndSettle();
    final pinnedTop = tester.getTopLeft(filter).dy;

    await tester.drag(scrollView, const Offset(0, -240));
    await tester.pumpAndSettle();

    expect(pinnedTop, lessThan(initialTop));
    expect(tester.getTopLeft(filter).dy, closeTo(pinnedTop, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('PornBox top content shares the page horizontal gutter', (
    tester,
  ) async {
    await pumpPreviewApp(
      tester,
      home: const MobilePornboxPage(),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.iOS,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
      wrap: (child) => Scaffold(body: child),
    );

    final titleLeft = tester
        .getTopLeft(
          find.descendant(
            of: find.byKey(const Key('mobile-pornbox-large-title')),
            matching: find.byType(Text),
          ),
        )
        .dx;
    final headerLeft = tester
        .getTopLeft(
          find
              .descendant(
                of: find.byKey(const Key('mobile-pornbox-total')),
                matching: find.byType(Text),
              )
              .first,
        )
        .dx;
    final collectionTitleLeft = tester.getTopLeft(find.text('视频合集')).dx;
    final collectionCardLeft = tester
        .getTopLeft(find.byKey(const Key('mobile-video-collection-card-1')))
        .dx;
    final videoCardLeft = tester
        .getTopLeft(find.byKey(const Key('video-summary-card-1')))
        .dx;

    expect(headerLeft, closeTo(titleLeft, 0.1));
    expect(collectionTitleLeft, closeTo(titleLeft, 0.1));
    expect(collectionCardLeft, closeTo(titleLeft, 0.1));
    expect(videoCardLeft, closeTo(titleLeft, 0.1));
  });
}

void _enqueueVideos(TestApiBundle bundle) {
  bundle.adapter.enqueueResponder(
    method: 'GET',
    path: '/videos',
    responder: (request, _) async => _jsonResponse(<String, dynamic>{
      'items': <Map<String, dynamic>>[
        for (var index = 0; index < 24; index++)
          <String, dynamic>{
            'id': index + 1,
            'title': '预览视频 ${index + 1}',
            'cover_width': 720,
            'cover_height': 1080,
            'media_count': 1,
            'can_play': true,
          },
      ],
      'page': 1,
      'page_size': 24,
      'total': 24,
    }),
  );
  bundle.adapter.enqueueResponder(
    method: 'GET',
    path: '/video-collections',
    responder: (request, _) async => _jsonResponse(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'name': '合集 1',
        'description': '',
        'item_count': 3,
        'cover_image': null,
      },
    ]),
  );
}

ResponseBody _jsonResponse(Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    200,
    headers: const <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}
