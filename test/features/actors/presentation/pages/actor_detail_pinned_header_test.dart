import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/presentation/pages/mobile/actor_detail_page.dart';
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
    _enqueueActorDetail(bundle);
    _enqueueMovies(bundle);
    _enqueueViewHistory(bundle);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  testWidgets('actor detail filter pins above scrolling profile and movies', (
    tester,
  ) async {
    await pumpPreviewApp(
      tester,
      home: const MobileActorDetailPage(actorId: 1),
      size: const Size(390, 844),
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.iOS,
      appPlatform: AppPlatform.mobile,
      bundle: bundle,
      wrap: (child) => Scaffold(body: child),
    );

    final filter = find.byKey(const Key('actor-detail-filter-trigger'));
    final scrollView = find.byType(CustomScrollView).first;
    final initialTop = tester.getTopLeft(filter).dy;

    await tester.drag(scrollView, const Offset(0, -260));
    await tester.pumpAndSettle();
    final pinnedTop = tester.getTopLeft(filter).dy;

    expect(pinnedTop, lessThan(initialTop));

    await tester.drag(scrollView, const Offset(0, -180));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(filter).dy, closeTo(pinnedTop, 0.1));
    expect(tester.takeException(), isNull);
  });
}

void _enqueueActorDetail(TestApiBundle bundle) {
  bundle.adapter.enqueueResponder(
    method: 'GET',
    path: '/actors/1',
    responder: (request, _) async => _jsonResponse(<String, dynamic>{
      'id': 1,
      'javdb_id': 'test-actor-1',
      'name': '演员一号',
      'alias_name': '演员一号',
      'profile_image': null,
      'is_subscribed': false,
      'movie_count': 24,
      'gender': 1,
      'age': 26,
      'height_cm': 160,
      'bust_cm': 88,
      'waist_cm': 58,
      'hips_cm': 88,
      'cup': 'D',
      'birthplace': '东京',
      'blood_type': 'O',
    }),
  );
}

void _enqueueMovies(TestApiBundle bundle) {
  bundle.adapter.enqueueResponder(
    method: 'GET',
    path: '/movies',
    responder: (request, _) async => _jsonResponse(<String, dynamic>{
      'items': <Map<String, dynamic>>[
        for (var index = 0; index < 24; index++)
          <String, dynamic>{
            'id': index + 1,
            'movie_number': 'TEST-${index + 1}',
            'title': '预览影片 ${index + 1}',
            'cover_image': null,
            'release_date': '2026-01-01T00:00:00',
            'duration_minutes': 120,
            'heat': 0,
            'is_subscribed': false,
            'can_play': true,
          },
      ],
      'page': 1,
      'page_size': 24,
      'total': 24,
    }),
  );
}

void _enqueueViewHistory(TestApiBundle bundle) {
  bundle.adapter.enqueueResponder(
    method: 'POST',
    path: '/view-history',
    responder: (request, _) async => ResponseBody.fromBytes(
      const <int>[],
      204,
      headers: const <String, List<String>>{},
    ),
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
