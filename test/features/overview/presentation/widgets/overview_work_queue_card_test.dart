import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/overview_work_queue_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';

void main() {
  testWidgets('展示工作台数据行与诊断槽', (WidgetTester tester) async {
    await _pump(
      tester,
      OverviewWorkQueueCard(
        downloading: 3,
        importing: 2,
        imported: 64,
        pendingIndexCount: 12,
        diagnostics: const SizedBox(key: Key('test-diagnostics')),
        onAllTasksTap: () {},
      ),
    );

    expect(
      find.byKey(const Key('overview-workbench-downloading')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('overview-workbench-importing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('overview-workbench-imported')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('overview-workbench-pending-index')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('overview-workbench-active')), findsOneWidget);
    expect(find.byKey(const Key('test-diagnostics')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('加载态使用真实行骨架', (WidgetTester tester) async {
    await _pump(
      tester,
      OverviewWorkQueueCard(
        downloading: 0,
        importing: 0,
        imported: 0,
        pendingIndexCount: 0,
        diagnostics: const SizedBox.shrink(),
        onAllTasksTap: () {},
        isLoading: true,
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is AppSkeletonizer && widget.enabled,
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('overview-workbench-empty')), findsNothing);
  });

  testWidgets('错误态触发卡内重试', (WidgetTester tester) async {
    var retried = false;
    await _pump(
      tester,
      OverviewWorkQueueCard(
        downloading: 0,
        importing: 0,
        imported: 0,
        pendingIndexCount: 0,
        diagnostics: const SizedBox.shrink(),
        onAllTasksTap: () {},
        errorMessage: '统计加载失败',
        onRetry: () => retried = true,
      ),
    );

    await tester.tap(find.byKey(const Key('overview-workbench-retry-button')));
    await tester.pump();
    expect(retried, isTrue);
  });

  testWidgets('空队列显示紧凑空态', (WidgetTester tester) async {
    await _pump(
      tester,
      OverviewWorkQueueCard(
        downloading: 0,
        importing: 0,
        imported: 0,
        pendingIndexCount: 0,
        diagnostics: const SizedBox.shrink(),
        onAllTasksTap: () {},
      ),
    );

    expect(find.byKey(const Key('overview-workbench-empty')), findsOneWidget);
    expect(
      find.byKey(const Key('overview-workbench-downloading')),
      findsNothing,
    );
  });

  testWidgets('全部任务入口可点击', (WidgetTester tester) async {
    var tapped = false;
    await _pump(
      tester,
      OverviewWorkQueueCard(
        downloading: 1,
        importing: 0,
        imported: 0,
        pendingIndexCount: 0,
        diagnostics: const SizedBox.shrink(),
        onAllTasksTap: () => tapped = true,
      ),
    );

    await tester.tap(find.byKey(const Key('overview-workbench-all-tasks')));
    await tester.pump();
    expect(tapped, isTrue);
  });
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: sakuraThemeData,
      locale: const Locale('zh'),
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      home: Scaffold(
        body: SingleChildScrollView(child: SizedBox(width: 360, child: child)),
      ),
    ),
  );
}
