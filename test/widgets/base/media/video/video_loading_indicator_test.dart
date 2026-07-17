import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/video/video_loading_indicator.dart';

void main() {
  testWidgets('uses the shared on-media loading presentation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: VideoLoadingIndicator()),
        ),
      ),
    );

    expect(find.text('正在加载…'), findsOneWidget);
    expect(find.byKey(const Key('video-loading-spinner')), findsOneWidget);
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byKey(const Key('video-loading-spinner')),
    );
    expect(spinner.color, sakuraThemeData.appTextPalette.onMedia);
  });
}
