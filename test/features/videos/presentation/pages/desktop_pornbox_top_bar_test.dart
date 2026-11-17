import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'desktop PornBox keeps the shell top bar fixed while the list scrolls',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final session = SessionStore.inMemory();
      await session.saveBaseUrl('https://api.example.com');
      await session.saveTokens(
        accessToken: 'test',
        refreshToken: 'test',
        expiresAt: DateTime(2099),
      );
      addTearDown(session.dispose);
      final bundle = await createTestApiBundle(session);
      addTearDown(bundle.dispose);
      _enqueueVideos(bundle);

      final router = buildDesktopRouter(sessionStore: session)
        ..go(desktopVideosPath);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: bundle.riverpodOverrides(),
          child: MaterialApp.router(
            theme: sakuraThemeData,
            locale: const Locale('zh'),
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
            builder: (context, child) =>
                OKToast(child: child ?? const SizedBox.shrink()),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final topBar = find.byKey(const Key('desktop-shell-topbar'));
      final filter = find.byKey(const Key('videos-filter-trigger'));
      final list = find.byKey(
        const PageStorageKey<String>('desktop:videos:list'),
      );
      final scrollable = find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      final topBarTop = tester.getTopLeft(topBar).dy;

      await tester.drag(list, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(0));
      final pinnedOffset = position.pixels;
      final filterTop = tester.getTopLeft(filter).dy;

      await tester.drag(list, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(topBar).dy, topBarTop);
      expect(tester.getTopLeft(filter).dy, closeTo(filterTop, 0.1));
      expect(position.pixels, greaterThan(pinnedOffset));
      expect(tester.takeException(), isNull);
    },
  );
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
    responder: (request, _) async => _jsonResponse(<dynamic>[]),
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
