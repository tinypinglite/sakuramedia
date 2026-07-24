import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_batch_selection.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(theme: sakuraThemeData, home: Scaffold(body: child));
  }

  testWidgets('移动多选顶栏只承载计数与全选，不放批量动作', (tester) async {
    await tester.pumpWidget(
      wrap(
        MovieBatchMobileSelectionHeader(
          keyPrefix: 'test',
          selectedCount: 2,
          visibleTotal: 8,
          allSelected: false,
          onToggleAll: () {},
          onExit: () {},
        ),
      ),
    );

    final selectAll = tester.widget<AppButton>(
      find.byKey(const Key('test-select-all-button')),
    );

    expect(selectAll.variant, AppButtonVariant.ghost);
    expect(selectAll.size, AppButtonSize.xSmall);
    expect(find.text('已选 2 部'), findsOneWidget);
    // 批量动作已下沉到底部条，顶栏不得再出现。
    expect(find.byKey(const Key('test-batch-subscribe-button')), findsNothing);
    expect(find.byKey(const Key('test-batch-unsubscribe-button')), findsNothing);
  });

  testWidgets('移动多选底部条区分订阅与取消订阅的视觉层级', (tester) async {
    await tester.pumpWidget(
      wrap(
        MovieBatchMobileSelectionBottomBar(
          keyPrefix: 'test',
          operatingAction: null,
          onSubscribe: () {},
          onUnsubscribe: () {},
        ),
      ),
    );

    final subscribe = tester.widget<AppButton>(
      find.byKey(const Key('test-batch-subscribe-button')),
    );
    final unsubscribe = tester.widget<AppButton>(
      find.byKey(const Key('test-batch-unsubscribe-button')),
    );

    expect(subscribe.variant, AppButtonVariant.primary);
    expect(unsubscribe.variant, AppButtonVariant.danger);
  });

  testWidgets('桌面批量栏的取消订阅同样使用危险样式', (tester) async {
    await tester.pumpWidget(
      wrap(
        MovieBatchSelectionToolbar(
          keyPrefix: 'desktop-test',
          selectedCount: 1,
          visibleTotal: 4,
          allSelected: false,
          operatingAction: null,
          onToggleAll: () {},
          onSubscribe: () {},
          onUnsubscribe: () {},
          onExit: () {},
        ),
      ),
    );

    final unsubscribe = tester.widget<AppButton>(
      find.byKey(const Key('desktop-test-batch-unsubscribe-button')),
    );
    expect(unsubscribe.variant, AppButtonVariant.danger);
  });
}
