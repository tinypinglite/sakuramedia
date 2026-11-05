import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/presentation/pages/desktop/actor_detail_page.dart';
import 'package:sakuramedia/features/actors/presentation/pages/mobile/actor_detail_page.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_detail_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_avatar.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  late TestApiBundle bundle;

  setUp(() async {
    final session = SessionStore.inMemory();
    await session.saveBaseUrl('https://api.example.com');
    await session.saveTokens(
      accessToken: 'test',
      refreshToken: 'test',
      expiresAt: DateTime(2030),
    );
    bundle = await createTestApiBundle(session);
  });
  tearDown(() => bundle.dispose());

  Future<void> pumpPage(
    WidgetTester tester,
    bool mobile,
    Map<String, dynamic> fields,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = mobile
        ? const Size(360, 760)
        : const Size(1100, 760);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors/1',
      body: actorJson(fields),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies',
      body: {
        'items': [
          for (var i = 0; i < 24; i++)
            {
              'javdb_id': 'movie-$i',
              'movie_number': 'TEST-$i',
              'title': '影片 $i',
              'is_subscribed': false,
              'can_play': true,
            },
        ],
        'page': 1,
        'page_size': 24,
        'total': 24,
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: OKToast(
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
            theme: mobile ? sakuraMobileThemeData : sakuraDesktopThemeData,
            home: Scaffold(
              body: mobile
                  ? const MobileActorDetailPage(actorId: 1)
                  : const DesktopActorDetailPage(actorId: 1),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final mobile in [false, true]) {
    for (final fields in <Map<String, dynamic>>[
      {},
      {
        'birthday': null,
        'age': null,
        'height_cm': null,
        'bust_cm': null,
        'waist_cm': null,
        'hips_cm': null,
        'cup': ' ',
        'birthplace': '',
        'blood_type': null,
      },
    ]) {
      testWidgets('${mobile ? '手机' : '桌面'}空资料不显示区域和展开入口 ${fields.length}', (
        tester,
      ) async {
        await pumpPage(tester, mobile, fields);
        expect(find.byKey(const Key('actor-profile-details')), findsNothing);
        expect(find.byKey(const Key('actor-profile-toggle')), findsNothing);
        expect(find.textContaining('暂无个人资料'), findsNothing);
        expect(find.text('24 部'), findsOneWidget);
      });
    }

    testWidgets('${mobile ? '手机' : '桌面'}仅显示已知三围，不为缺失字段占位', (tester) async {
      await pumpPage(tester, mobile, {'waist_cm': 58});
      expect(find.textContaining('腰围  58 cm'), findsOneWidget);
      expect(find.textContaining('胸围'), findsNothing);
      expect(find.textContaining('臀围'), findsNothing);
      expect(find.byKey(const Key('actor-profile-toggle')), findsNothing);
    });

    testWidgets('${mobile ? '手机' : '桌面'}完整资料、订阅和吸顶滚动', (tester) async {
      await pumpPage(tester, mobile, fullProfile);
      final profile = find.byKey(const Key('actor-profile-details'));
      if (!mobile) {
        final name = find.byKey(const Key('actor-detail-name'));
        final avatar = find.byType(ActorAvatar);
        expect(tester.getTopLeft(profile).dx, tester.getTopLeft(name).dx);
        expect(
          tester.getTopLeft(profile).dx,
          greaterThan(tester.getTopRight(avatar).dx),
        );
        expect(
          tester.getTopLeft(profile).dy,
          lessThan(tester.getBottomLeft(avatar).dy),
        );
      }
      if (mobile) {
        expect(find.text('展开资料'), findsNothing);
        expect(
          tester.getTopLeft(profile).dx,
          tester
              .getTopLeft(find.byKey(const Key('actor-detail-filter-trigger')))
              .dx,
        );
        expect(
          tester.getTopRight(find.byKey(const Key('actor-profile-toggle'))).dx,
          tester
              .getTopRight(find.byKey(const Key('mobile-actor-detail-header')))
              .dx,
        );
        expect(find.textContaining('年龄  33岁'), findsOneWidget);
        expect(find.textContaining('出生地'), findsNothing);
        await tester.tap(find.byKey(const Key('actor-profile-toggle')));
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('1993年8月16日 · 33岁'), findsOneWidget);
      expect(find.textContaining('出生地  东京都'), findsOneWidget);
      expect(find.textContaining('身高  159 cm'), findsOneWidget);
      expect(find.textContaining('罩杯  F'), findsOneWidget);
      expect(find.textContaining('血型  O'), findsOneWidget);
      for (final value in ['胸围  84 cm', '腰围  58 cm', '臀围  88 cm']) {
        expect(find.textContaining(value), findsOneWidget);
      }
      bundle.adapter.enqueueJson(
        method: 'PUT',
        path: '/actors/1/subscription',
        statusCode: 204,
      );
      await tester.tap(
        find.byKey(
          Key('${mobile ? 'mobile-' : ''}actor-detail-subscription-1'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('出生地  东京都'), findsOneWidget);
      expect(bundle.adapter.hitCount('PUT', '/actors/1/subscription'), 1);
      if (mobile) {
        await tester.tap(find.byKey(const Key('actor-profile-toggle')));
        await tester.pumpAndSettle();
        expect(find.textContaining('出生地'), findsNothing);
      }
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final filter = find.byKey(const Key('actor-detail-filter-trigger'));
      scroll.jumpTo(220);
      await tester.pumpAndSettle();
      final pinnedTop = tester.getTopLeft(filter).dy;
      scroll.jumpTo(350);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(filter).dy, pinnedTop);
      expect(scroll.pixels, 350);
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-summary-card-TEST-23')).hitTestable(),
        findsOneWidget,
      );
      expect(bundle.adapter.hitCount('GET', '/actors/1'), 1);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('手机只有摘要字段时没有展开入口，刷新清空资料后区域消失', (tester) async {
    await pumpPage(tester, true, {'age': 33, 'height_cm': 159, 'cup': 'F'});
    expect(find.byKey(const Key('actor-profile-toggle')), findsNothing);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors/1',
      body: actorJson({}),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MobileActorDetailPage)),
    );
    final refresh = container.read(actorDetailProvider(1).notifier).refresh();
    await tester.pumpAndSettle();
    await refresh;
    expect(find.byKey(const Key('actor-profile-details')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Map<String, dynamic> actorJson(Map<String, dynamic> fields) => {
  'id': 1,
  'javdb_id': 'actor-1',
  'name': '演员一号',
  'alias_name': '',
  'profile_image': null,
  'is_subscribed': false,
  ...fields,
};

const fullProfile = <String, dynamic>{
  'birthday': '1993-08-16',
  'age': 33,
  'height_cm': 159,
  'bust_cm': 84,
  'waist_cm': 58,
  'hips_cm': 88,
  'cup': 'F',
  'birthplace': '东京都',
  'blood_type': 'O',
};
