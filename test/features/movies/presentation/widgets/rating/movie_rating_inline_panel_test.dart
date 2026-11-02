import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/rating/movie_rating_inline_panel.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
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

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: OKToast(
        child: MaterialApp(
          theme: sakuraThemeData,
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
  }

  void enqueueRatingData() {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movie-rating-dimensions',
      body: _dimensionsJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001/rating',
      body: _ratingJson(total: 3.5, looks: 4, plot: 3),
    );
  }

  testWidgets('内联面板展示维度分值，点星即自动保存', (tester) async {
    enqueueRatingData();
    await tester.pumpWidget(
      wrap(const MovieRatingInlinePanel(movieNumber: 'ABC-001')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-rating-score-1-4')), findsOneWidget);
    expect(find.byKey(const Key('movie-rating-score-2-3')), findsOneWidget);
    expect(
      _starIcon(tester, const Key('movie-rating-score-1-4')),
      Icons.star_rounded,
    );
    expect(
      _starIcon(tester, const Key('movie-rating-score-1-5')),
      Icons.star_border_rounded,
    );

    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/ABC-001/rating',
      body: _ratingJson(total: 4.0, looks: 5, plot: 3),
    );
    await tester.tap(find.byKey(const Key('movie-rating-score-1-5')));
    await tester.pumpAndSettle();

    final saveRequest = bundle.adapter.requests.lastWhere(
      (request) => request.method == 'PUT',
    );
    expect(saveRequest.body, <String, dynamic>{
      'values': <String, dynamic>{'1': 5, '2': 3},
    });
    expect(
      _starIcon(tester, const Key('movie-rating-score-1-5')),
      Icons.star_rounded,
    );
  });

  testWidgets('评分加载失败后重试，再打分不会覆盖其它维度', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movie-rating-dimensions',
      body: _dimensionsJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001/rating',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'boom'},
    );
    await tester.pumpWidget(
      wrap(const MovieRatingInlinePanel(movieNumber: 'ABC-001')),
    );
    await tester.pumpAndSettle();
    expect(find.text('评分加载失败'), findsOneWidget);

    // 重试成功：真实评分必须回填，不能停留在空手状态。
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001/rating',
      body: _ratingJson(total: 3.5, looks: 4, plot: 3),
    );
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(
      _starIcon(tester, const Key('movie-rating-score-1-4')),
      Icons.star_rounded,
    );

    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/ABC-001/rating',
      body: _ratingJson(total: 4.0, looks: 5, plot: 3),
    );
    await tester.tap(find.byKey(const Key('movie-rating-score-1-5')));
    await tester.pumpAndSettle();

    final saveRequest = bundle.adapter.requests.lastWhere(
      (request) => request.method == 'PUT',
    );
    expect(saveRequest.body, <String, dynamic>{
      'values': <String, dynamic>{'1': 5, '2': 3},
    });
  });

  testWidgets('再次点击已选分值可清除，全部清空后删除评分', (tester) async {
    enqueueRatingData();
    await tester.pumpWidget(
      wrap(const MovieRatingInlinePanel(movieNumber: 'ABC-001')),
    );
    await tester.pumpAndSettle();

    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/ABC-001/rating',
      body: _ratingJson(total: 3.0, looks: null, plot: 3),
    );
    await tester.tap(find.byKey(const Key('movie-rating-score-1-4')));
    await tester.pumpAndSettle();
    expect(
      bundle.adapter.requests.lastWhere((r) => r.method == 'PUT').body,
      <String, dynamic>{
        'values': <String, dynamic>{'2': 3},
      },
    );

    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/movies/ABC-001/rating',
      statusCode: 204,
    );
    await tester.tap(find.byKey(const Key('movie-rating-score-2-3')));
    await tester.pumpAndSettle();

    expect(
      bundle.adapter.requests.any((request) => request.method == 'DELETE'),
      isTrue,
    );
    expect(find.byIcon(Icons.star_rounded), findsNothing);
  });

  testWidgets('一行放得下就并排，放不下自动换行', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    enqueueRatingData();
    await tester.pumpWidget(
      wrap(const MovieRatingInlinePanel(movieNumber: 'ABC-001')),
    );
    await tester.pumpAndSettle();

    double topOf(int dimensionId) => tester
        .getTopLeft(find.byKey(Key('movie-rating-score-$dimensionId-1')))
        .dy;

    expect(topOf(2), topOf(1));

    tester.view.physicalSize = const Size(260, 800);
    await tester.pumpAndSettle();
    expect(topOf(2), greaterThan(topOf(1)));
  });

  testWidgets('10 分制展示十颗星并保存十分', (tester) async {
    tester.view.physicalSize = const Size(260, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movie-rating-dimensions',
      body: _dimensionsJson(firstMax: 10),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001/rating',
      body: _ratingJson(total: 3.5, looks: 9, plot: 3, looksMax: 10),
    );
    await tester.pumpWidget(
      wrap(const MovieRatingInlinePanel(movieNumber: 'ABC-001')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('movie-rating-score-1-10')), findsOneWidget);

    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/ABC-001/rating',
      body: _ratingJson(total: 4.5, looks: 10, plot: 3, looksMax: 10),
    );
    await tester.tap(find.byKey(const Key('movie-rating-score-1-10')));
    await tester.pumpAndSettle();

    final saveRequest = bundle.adapter.requests.lastWhere(
      (request) => request.method == 'PUT',
    );
    expect(saveRequest.body, <String, dynamic>{
      'values': <String, dynamic>{'1': 10, '2': 3},
    });
  });

  testWidgets('百分制使用数字输入并在提交和失焦时保存', (tester) async {
    tester.view.physicalSize = const Size(260, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movie-rating-dimensions',
      body: _dimensionsJson(firstMax: 100),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001/rating',
      body: _ratingJson(total: 3.5, looks: 75, plot: 3, looksMax: 100),
    );
    await tester.pumpWidget(
      wrap(const MovieRatingInlinePanel(movieNumber: 'ABC-001')),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('movie-rating-score-1-field'));
    expect(field, findsOneWidget);
    expect(find.text('75'), findsOneWidget);

    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/ABC-001/rating',
      body: _ratingJson(total: 4.5, looks: 100, plot: 3, looksMax: 100),
    );
    await tester.enterText(field, '100');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final saveRequest = bundle.adapter.requests.lastWhere(
      (request) => request.method == 'PUT',
    );
    expect(saveRequest.body, <String, dynamic>{
      'values': <String, dynamic>{'1': 100, '2': 3},
    });

    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/ABC-001/rating',
      body: _ratingJson(total: 4.4, looks: 99, plot: 3, looksMax: 100),
    );
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, '99');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final blurSaveRequest = bundle.adapter.requests.lastWhere(
      (request) => request.method == 'PUT',
    );
    expect(blurSaveRequest.body, <String, dynamic>{
      'values': <String, dynamic>{'1': 99, '2': 3},
    });
  });

  testWidgets('百分制非法值不保存，清除后全部为空则删除评分', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movie-rating-dimensions',
      body: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'name': '颜值',
          'min_value': 1,
          'max_value': 100,
          'weight': 1.0,
          'has_scores': true,
        },
      ],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001/rating',
      body: _ratingJson(total: 4.0, looks: 80, plot: null, looksMax: 100),
    );
    await tester.pumpWidget(
      wrap(const MovieRatingInlinePanel(movieNumber: 'ABC-001')),
    );
    await tester.pumpAndSettle();

    final requestCountBeforeInvalid = bundle.adapter.requests.length;
    final field = find.byKey(const Key('movie-rating-score-1-field'));
    await tester.enterText(field, '101');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(bundle.adapter.requests.length, requestCountBeforeInvalid);
    expect(find.text('请输入 1–100 的整数'), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .controller
          .text,
      '80',
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/movies/ABC-001/rating',
      statusCode: 204,
    );
    await tester.tap(find.byTooltip('清除评分'));
    await tester.pumpAndSettle();

    expect(
      bundle.adapter.requests.any((request) => request.method == 'DELETE'),
      isTrue,
    );
  });
}

IconData _starIcon(WidgetTester tester, Key key) {
  return tester
      .widget<Icon>(
        find.descendant(of: find.byKey(key), matching: find.byType(Icon)),
      )
      .icon!;
}

List<Map<String, dynamic>> _dimensionsJson({
  int firstMax = 5,
  bool firstHasScores = false,
}) => <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 1,
    'name': '颜值',
    'min_value': 1,
    'max_value': firstMax,
    'weight': 1.0,
    'has_scores': firstHasScores,
  },
  <String, dynamic>{
    'id': 2,
    'name': '剧情',
    'min_value': 1,
    'max_value': 5,
    'weight': 1.0,
    'has_scores': false,
  },
];

Map<String, dynamic> _ratingJson({
  required double total,
  required int? looks,
  required int? plot,
  int looksMax = 5,
}) => <String, dynamic>{
  'movie_number': 'ABC-001',
  'rated': looks != null || plot != null,
  'total_score': looks == null && plot == null ? null : total,
  'updated_at': '2026-10-20T10:00:00',
  'values': <Map<String, dynamic>>[
    if (looks != null)
      <String, dynamic>{
        'dimension_id': 1,
        'name': '颜值',
        'value': looks,
        'min_value': 1,
        'max_value': looksMax,
      },
    if (plot != null)
      <String, dynamic>{
        'dimension_id': 2,
        'name': '剧情',
        'value': plot,
        'min_value': 1,
        'max_value': 5,
      },
  ],
};
