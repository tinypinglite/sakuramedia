import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/pages/mobile/actor_filter_drawer.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('女优筛选抽屉与桌面面板同构且即时生效', (tester) async {
    final applied = <ActorFilterState>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    await showMobileActorFilterDrawer(
                      context,
                      current: ActorFilterState.initial,
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

    // 抽屉内容与桌面浮层面板同构：只有筛选分节 + footer。
    expect(find.text('订阅筛选'), findsOneWidget);
    expect(find.text('性别筛选'), findsOneWidget);
    expect(find.text('快捷筛选'), findsNothing);
    expect(find.text('确定'), findsNothing);
    expect(find.text('完成'), findsNothing);

    await tester.tap(find.text('未订阅'));
    await tester.pumpAndSettle();

    expect(applied, hasLength(1));
    expect(
      applied.single.subscriptionStatus,
      ActorSubscriptionStatus.unsubscribed,
    );
    expect(find.text('订阅筛选'), findsOneWidget);

    await tester.tap(find.text('重置'));
    await tester.pumpAndSettle();

    expect(applied, hasLength(2));
    expect(applied.last.isDefault, isTrue);
  });
}
