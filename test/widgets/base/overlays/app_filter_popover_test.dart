import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/navigation/app_filter_entry_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';

void main() {
  testWidgets('打开筛选浮层后隐藏触发器 Tooltip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData.copyWith(platform: TargetPlatform.macOS),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                height: 44,
                child: AppFilterPopover(
                  triggerLabel: '全部媒体',
                  panelKey: const Key('test-filter-panel'),
                  triggerBuilder: (context, isOpen, toggle) =>
                      AppFilterEntryButton(
                        key: const Key('test-filter-trigger'),
                        label: '全部媒体',
                        tooltip: '筛选',
                        trailingIcon: isOpen
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        onTap: toggle,
                      ),
                  panelBuilder: (_) => const SizedBox(
                    key: Key('test-filter-panel-body'),
                    height: 120,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final triggerFinder = find.byKey(const Key('test-filter-trigger'));
    final tooltipFinder = find.descendant(
      of: triggerFinder,
      matching: find.byType(Tooltip),
    );
    final tooltipState = tester.state<TooltipState>(tooltipFinder);

    expect(tooltipState.ensureTooltipVisible(), isTrue);
    await tester.pump();
    expect(find.byType(RawTooltip), findsOneWidget);

    await tester.tap(triggerFinder);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('test-filter-panel')), findsOneWidget);
    expect(find.byType(RawTooltip), findsNothing);
    expect(
      tester.state<TooltipState>(tooltipFinder).ensureTooltipVisible(),
      isFalse,
    );

    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('test-filter-panel')), findsNothing);
    expect(find.byType(RawTooltip), findsOneWidget);
    expect(
      tester.state<TooltipState>(tooltipFinder).ensureTooltipVisible(),
      isTrue,
    );
  });
}
