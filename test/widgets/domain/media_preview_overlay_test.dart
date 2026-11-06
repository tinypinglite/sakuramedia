import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';

void main() {
  testWidgets('media preview auto uses a drawer on mobile', (tester) async {
    await _pumpHost(
      tester,
      appPlatform: AppPlatform.mobile,
      theme: buildSakuraMobileThemeData(),
      platform: TargetPlatform.android,
    );

    final result = showMediaPreviewOverlay(
      context: tester.element(find.byType(Scaffold)),
      variant: AppAdaptiveModalVariant.auto,
      drawerKey: const Key('media-preview-test-drawer'),
      builder: (_) => Builder(
        builder: (context) =>
            Text('${AppAdaptiveModalShellScope.maybeIsDrawer(context)}'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('media-preview-test-drawer')), findsOneWidget);
    expect(find.text('true'), findsOneWidget);

    Navigator.of(
      tester.element(find.byKey(const Key('media-preview-test-drawer'))),
    ).pop();
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('media preview auto uses a dialog on desktop', (tester) async {
    await _pumpHost(
      tester,
      appPlatform: AppPlatform.desktop,
      theme: buildSakuraDesktopThemeData(),
      platform: TargetPlatform.macOS,
    );

    final result = showMediaPreviewOverlay(
      context: tester.element(find.byType(Scaffold)),
      variant: AppAdaptiveModalVariant.auto,
      builder: (_) => Builder(
        builder: (context) =>
            Text('${AppAdaptiveModalShellScope.maybeIsDrawer(context)}'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('image-search-result-preview-dialog')),
      findsOneWidget,
    );
    expect(find.text('false'), findsOneWidget);

    Navigator.of(
      tester.element(
        find.byKey(const Key('image-search-result-preview-dialog')),
      ),
    ).pop();
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required AppPlatform appPlatform,
  required ThemeData theme,
  required TargetPlatform platform,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: theme.copyWith(platform: platform),
      home: AppPlatformScope(
        platform: appPlatform,
        child: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
}
