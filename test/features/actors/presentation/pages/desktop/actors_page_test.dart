import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/pages/desktop/actors_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_filter_entry_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
  });

  testWidgets('桌面女优页顶栏与移动端同构：筛选入口 + 总数信息胶囊', (WidgetTester tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _actorsJson(total: 3),
    );

    await _pumpActorsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    // 顶栏收敛到 AppListHeader，旧的 AppFilterTotalHeader 不再出现。
    expect(find.byType(AppListHeader), findsOneWidget);
    expect(find.byType(AppFilterTotalHeader), findsNothing);

    // 筛选入口与移动端共用同一个按钮，摘要只报订阅状态这一主维度。
    final entry = tester.widget<AppFilterEntryButton>(
      find.byType(AppFilterEntryButton),
    );
    expect(entry.label, '已订阅');

    // 总数走只读信息胶囊，不再是顶栏右侧裸文本。
    expect(
      find.descendant(
        of: find.byKey(const Key('app-list-header-information-slots')),
        matching: find.byKey(const Key('actors-page-total')),
      ),
      findsOneWidget,
    );
    expect(find.text('3 位'), findsOneWidget);
  });

  testWidgets('桌面筛选浮层与移动抽屉同构，选中即时生效并重新拉取', (WidgetTester tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _actorsJson(total: 3),
    );

    await _pumpActorsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('actors-filter-trigger')));
    await tester.pumpAndSettle();

    // 面板内容与移动抽屉逐节一致，重置在 footer 里。
    expect(find.byKey(const Key('actors-filter-panel')), findsOneWidget);
    expect(find.text('订阅筛选'), findsOneWidget);
    expect(find.text('性别筛选'), findsOneWidget);
    expect(find.text('确定'), findsNothing);

    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _actorsJson(total: 1),
    );

    await tester.tap(find.text('未订阅'));
    await tester.pumpAndSettle();

    // 即时生效：不需要「确定」，选中当场触发带新参数的重新拉取。
    final lastRequest = bundle.adapter.requests.last;
    expect(lastRequest.path, '/actors');
    expect(lastRequest.uri.queryParameters['subscription_status'], 'unsubscribed');
    expect(find.text('1 位'), findsOneWidget);

    final entry = tester.widget<AppFilterEntryButton>(
      find.byType(AppFilterEntryButton),
    );
    expect(entry.label, '未订阅');
  });
}

Future<void> _pumpActorsPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<ActorsApi>.value(value: bundle.actorsApi),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          home: const Scaffold(body: DesktopActorsPage()),
        ),
      ),
    ),
  );
}

Map<String, dynamic> _actorsJson({
  int page = 1,
  int pageSize = 20,
  int total = 1,
  List<Map<String, dynamic>>? items,
}) {
  return <String, dynamic>{
    'items': items ?? <Map<String, dynamic>>[_actorItem()],
    'page': page,
    'page_size': pageSize,
    'total': total,
  };
}

Map<String, dynamic> _actorItem({
  int id = 1,
  String name = '演员一号',
  bool isSubscribed = true,
}) {
  return <String, dynamic>{
    'id': id,
    'javdb_id': 'javdb-$id',
    'name': name,
    'alias_name': '',
    'profile_image': null,
    'is_subscribed': isSubscribed,
  };
}
