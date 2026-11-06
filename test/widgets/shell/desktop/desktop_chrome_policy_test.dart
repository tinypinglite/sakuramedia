import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/shell/desktop/desktop_chrome_policy.dart';

void main() {
  group('DesktopChromePolicy', () {
    testWidgets('macOS uses glass sidebar and custom traffic lights', (
      tester,
    ) async {
      final policy = await _readPolicy(tester, TargetPlatform.macOS);

      expect(policy.usesGlassSidebar, isTrue);
      expect(policy.usesMacTrafficLights, isTrue);
      expect(policy.usesWindowsCaption, isFalse);
      expect(policy.sidebarToggleLeft, greaterThan(0));
    });

    testWidgets('Windows uses glass sidebar and native caption', (
      tester,
    ) async {
      final policy = await _readPolicy(tester, TargetPlatform.windows);

      expect(policy.usesGlassSidebar, isTrue);
      expect(policy.usesMacTrafficLights, isFalse);
      expect(policy.usesWindowsCaption, isTrue);
      expect(policy.sidebarToggleLeft, greaterThan(0));
    });

    testWidgets('other desktop platforms use solid sidebar chrome', (
      tester,
    ) async {
      final policy = await _readPolicy(tester, TargetPlatform.linux);

      expect(policy.usesGlassSidebar, isFalse);
      expect(policy.usesMacTrafficLights, isFalse);
      expect(policy.usesWindowsCaption, isFalse);
    });
  });
}

Future<DesktopChromePolicy> _readPolicy(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    late DesktopChromePolicy policy;
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraDesktopThemeData,
        home: Builder(
          builder: (context) {
            policy = DesktopChromePolicy.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return policy;
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}
