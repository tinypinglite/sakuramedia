import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart' show OKToast;
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';

void main() {
  test('default toast duration is three seconds', () {
    expect(kAppToastDuration, const Duration(seconds: 3));
  });

  Future<void> pumpToastApp(
    WidgetTester tester, {
    bool highContrast = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraDesktopThemeData,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(highContrast: highContrast),
            child: OKToast(child: child ?? const SizedBox.shrink()),
          );
        },
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );
    await tester.pump();
  }

  testWidgets('all toast tones render without shader errors', (tester) async {
    await pumpToastApp(tester);
    for (final tone in AppToastTone.values) {
      showToast(
        '状态提示',
        tone: tone,
        duration: const Duration(milliseconds: 250),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      dismissAllToast();
      await tester.pump();
    }
  });

  testWidgets('high contrast fallback renders without errors', (tester) async {
    await pumpToastApp(tester, highContrast: true);
    showToast(
      '高对比度提示',
      tone: AppToastTone.warning,
      duration: const Duration(milliseconds: 250),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    dismissAllToast();
    await tester.pump();
  });
}
