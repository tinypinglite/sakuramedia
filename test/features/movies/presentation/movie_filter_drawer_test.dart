import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_filter_drawer.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('影片筛选抽屉与桌面面板同构且即时生效', (tester) async {
    final applied = <MovieFilterState>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    await showMobileMovieFilterDrawer(
                      context,
                      current: MovieFilterState.initial,
                      onChanged: applied.add,
                    );
                  },
                  child: const Text('打开筛选'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('打开筛选'));
    await tester.pumpAndSettle();

    // 抽屉内容与桌面浮层面板同构：只有筛选分节 + footer，没有标题行、
    // 没有快捷筛选、没有确定按钮。
    expect(find.text('状态筛选'), findsOneWidget);
    expect(find.text('合集类型'), findsOneWidget);
    expect(find.text('筛选'), findsNothing);
    expect(find.text('确定'), findsNothing);
    expect(find.text('完成'), findsNothing);

    await tester.tap(find.text('已订阅'));
    await tester.pumpAndSettle();

    // 点完立刻生效，抽屉不关。
    expect(applied, hasLength(1));
    expect(applied.single.status, MovieStatusFilter.subscribed);
    expect(find.text('状态筛选'), findsOneWidget);

    // 重置在 footer 里，与桌面面板同一个 AppFilterPanelFooter。
    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();

    expect(applied, hasLength(2));
    expect(applied.last.isDefault, isTrue);
  });
}
