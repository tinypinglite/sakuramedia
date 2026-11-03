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

  testWidgets('维度内部保持单行，维度之间按宽度换行', (tester) async {
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
    double centerY(Key key) => tester.getCenter(find.byKey(key)).dy;

    expect(topOf(2), topOf(1));
    expect(
      centerY(const Key('movie-rating-name-1')),
      moreOrLessEquals(
        centerY(const Key('movie-rating-stars-1')),
        epsilon: 0.1,
      ),
    );

    tester.view.physicalSize = const Size(260, 800);
    await tester.pumpAndSettle();
    expect(topOf(2), greaterThan(topOf(1)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('10 分制显示数值，点击后原位编辑并保存十分', (tester) async {
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

    final value = find.byKey(const Key('movie-rating-value-1'));
    final field = find.byKey(const Key('movie-rating-score-1-field'));
    expect(value, findsOneWidget);
    expect(find.text('9/10'), findsOneWidget);
    expect(field, findsNothing);
    expect(find.byKey(const Key('movie-rating-score-1-10')), findsNothing);

    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/ABC-001/rating',
      body: _ratingJson(total: 4.5, looks: 10, plot: 3, looksMax: 10),
    );
    await tester.tap(value);
    await tester.pumpAndSettle();
    expect(field, findsOneWidget);
    expect(tester.getSize(field).width, lessThanOrEqualTo(52));
    expect(_fieldText(tester, field), '9');

    await tester.enterText(field, '10');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final saveRequest = bundle.adapter.requests.lastWhere(
      (request) => request.method == 'PUT',
    );
    expect(saveRequest.body, <String, dynamic>{
      'values': <String, dynamic>{'1': 10, '2': 3},
    });
    expect(field, findsNothing);
    expect(find.text('10/10'), findsOneWidget);
  });

  testWidgets('百分制平时显示数值，点击后在提交和失焦时保存', (tester) async {
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

    final value = find.byKey(const Key('movie-rating-value-1'));
    final field = find.byKey(const Key('movie-rating-score-1-field'));
    expect(value, findsOneWidget);
    expect(find.text('75/100'), findsOneWidget);
    expect(field, findsNothing);

    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/ABC-001/rating',
      body: _ratingJson(total: 4.5, looks: 100, plot: 3, looksMax: 100),
    );
    await tester.tap(value);
    await tester.pumpAndSettle();
    expect(field, findsOneWidget);
    expect(tester.getSize(field).width, lessThanOrEqualTo(52));
    expect(_fieldText(tester, field), '75');

    await tester.enterText(field, '100');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final saveRequest = bundle.adapter.requests.lastWhere(
      (request) => request.method == 'PUT',
    );
    expect(saveRequest.body, <String, dynamic>{
      'values': <String, dynamic>{'1': 100, '2': 3},
    });
    expect(field, findsNothing);
    expect(find.text('100/100'), findsOneWidget);

    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/movies/ABC-001/rating',
      body: _ratingJson(total: 4.4, looks: 99, plot: 3, looksMax: 100),
    );
    await tester.tap(value);
    await tester.pumpAndSettle();
    await tester.enterText(field, '99');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final blurSaveRequest = bundle.adapter.requests.lastWhere(
      (request) => request.method == 'PUT',
    );
    expect(blurSaveRequest.body, <String, dynamic>{
      'values': <String, dynamic>{'1': 99, '2': 3},
    });
    expect(field, findsNothing);
    expect(find.text('99/100'), findsOneWidget);
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
    final value = find.byKey(const Key('movie-rating-value-1'));
    final field = find.byKey(const Key('movie-rating-score-1-field'));
    await tester.tap(value);
    await tester.pumpAndSettle();
    await tester.enterText(field, '101');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(bundle.adapter.requests.length, requestCountBeforeInvalid);
    expect(find.text('请输入 1–100 的整数'), findsOneWidget);
    expect(field, findsNothing);
    expect(find.text('80/100'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/movies/ABC-001/rating',
      statusCode: 204,
    );
    await tester.tap(value);
    await tester.pumpAndSettle();
    await tester.enterText(field, '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      bundle.adapter.requests.any((request) => request.method == 'DELETE'),
      isTrue,
    );
    expect(find.text('未评分'), findsOneWidget);
    expect(field, findsNothing);

    await tester.tap(value);
    await tester.pumpAndSettle();
    expect(field, findsOneWidget);
    expect(_fieldText(tester, field), isEmpty);
  });

  testWidgets('混合分制保持紧凑横排，窄屏只在维度之间换行', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movie-rating-dimensions',
      body: _mixedDimensionsJson(),
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/movies/ABC-001/rating',
      body: _mixedRatingJson(),
    );
    await tester.pumpWidget(
      wrap(const MovieRatingInlinePanel(movieNumber: 'ABC-001')),
    );
    await tester.pumpAndSettle();

    double centerY(Key key) => tester.getCenter(find.byKey(key)).dy;
    final firstLabelCenterY = centerY(const Key('movie-rating-name-1'));
    final starCenterY = centerY(const Key('movie-rating-stars-1'));
    for (final dimensionId in <int>[1, 2, 3]) {
      expect(
        centerY(Key('movie-rating-name-$dimensionId')),
        moreOrLessEquals(firstLabelCenterY, epsilon: 0.1),
      );
      for (var score = 1; score <= 5; score++) {
        expect(
          centerY(Key('movie-rating-score-$dimensionId-$score')),
          moreOrLessEquals(starCenterY, epsilon: 0.1),
        );
      }
    }
    for (final dimensionId in <int>[4, 5]) {
      expect(
        centerY(Key('movie-rating-name-$dimensionId')),
        moreOrLessEquals(firstLabelCenterY, epsilon: 0.1),
      );
      expect(
        centerY(Key('movie-rating-value-$dimensionId')),
        moreOrLessEquals(starCenterY, epsilon: 0.1),
      );
    }
    expect(find.text('58/100'), findsOneWidget);
    expect(find.text('75/100'), findsOneWidget);
    expect(find.byKey(const Key('movie-rating-score-4-field')), findsNothing);
    expect(find.byKey(const Key('movie-rating-score-5-field')), findsNothing);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(390, 800);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('movie-rating-dimension-1'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('movie-rating-dimension-5'))).dy,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

IconData _starIcon(WidgetTester tester, Key key) {
  return tester
      .widget<Icon>(
        find.descendant(of: find.byKey(key), matching: find.byType(Icon)),
      )
      .icon!;
}

String _fieldText(WidgetTester tester, Finder field) {
  return tester
      .widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      )
      .controller
      .text;
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

List<Map<String, dynamic>> _mixedDimensionsJson() => <Map<String, dynamic>>[
  _dimensionJson(id: 1, name: '颜值'),
  _dimensionJson(id: 2, name: '身材'),
  _dimensionJson(id: 3, name: '妆容'),
  _dimensionJson(id: 4, name: 'Auto-颜值', maxValue: 100),
  _dimensionJson(id: 5, name: 'Auto-身材', maxValue: 100),
];

Map<String, dynamic> _mixedRatingJson() => <String, dynamic>{
  'movie_number': 'ABC-001',
  'rated': true,
  'total_score': 3.9,
  'updated_at': '2026-10-20T10:00:00',
  'values': <Map<String, dynamic>>[
    _ratingValueJson(id: 1, name: '颜值', value: 4),
    _ratingValueJson(id: 2, name: '身材', value: 5),
    _ratingValueJson(id: 3, name: '妆容', value: 3),
    _ratingValueJson(id: 4, name: 'Auto-颜值', value: 58, maxValue: 100),
    _ratingValueJson(id: 5, name: 'Auto-身材', value: 75, maxValue: 100),
  ],
};

Map<String, dynamic> _dimensionJson({
  required int id,
  required String name,
  int maxValue = 5,
}) => <String, dynamic>{
  'id': id,
  'name': name,
  'min_value': 1,
  'max_value': maxValue,
  'weight': 1.0,
  'has_scores': true,
};

Map<String, dynamic> _ratingValueJson({
  required int id,
  required String name,
  required int value,
  int maxValue = 5,
}) => <String, dynamic>{
  'dimension_id': id,
  'name': name,
  'value': value,
  'min_value': 1,
  'max_value': maxValue,
};
