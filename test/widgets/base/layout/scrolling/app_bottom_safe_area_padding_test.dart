import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_bottom_safe_area_padding.dart';

void main() {
  testWidgets('底部安全区与额外留白叠加到内容下方', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
          child: Align(
            alignment: Alignment.topLeft,
            child: AppBottomSafeAreaPadding(
              extra: 8,
              child: const SizedBox(
                key: Key('safe-area-content'),
                width: 200,
                height: 100,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(AppBottomSafeAreaPadding)),
      const Size(200, 142),
    );
    expect(tester.getRect(find.byKey(const Key('safe-area-content'))).top, 0);
  });
}
