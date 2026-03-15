import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/media_preview_action_grid.dart';

void main() {
  testWidgets('media preview action grid renders wrap layout actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: MediaPreviewActionGrid(
            actions: const [
              MediaPreviewActionItem(
                label: '相似图片',
                icon: Icons.image_search_outlined,
              ),
              MediaPreviewActionItem(
                label: '保存到本地',
                icon: Icons.download_outlined,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('相似图片'), findsOneWidget);
    expect(find.text('保存到本地'), findsOneWidget);
    expect(find.byType(Wrap), findsOneWidget);
  });

  testWidgets('media preview action grid renders horizontal scroll layout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: MediaPreviewActionGrid(
            layout: MediaPreviewActionGridLayout.horizontalScroll,
            actions: const [
              MediaPreviewActionItem(
                label: '相似图片',
                icon: Icons.image_search_outlined,
              ),
              MediaPreviewActionItem(
                label: '保存到本地',
                icon: Icons.download_outlined,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(Wrap), findsNothing);
  });

  testWidgets('media preview action tile triggers tap callback', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: MediaPreviewActionGrid(
            actions: [
              MediaPreviewActionItem(
                label: '播放',
                icon: Icons.play_circle_outline_rounded,
                onTap: () {
                  tapped = true;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(
      find.ancestor(of: find.text('播放'), matching: find.byType(InkWell)),
    );
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets(
    'media preview action tile keeps disabled state when onTap is null',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: MediaPreviewActionGrid(
              actions: const [
                MediaPreviewActionItem(
                  label: '影片详情',
                  icon: Icons.info_outline_rounded,
                  onTap: null,
                ),
              ],
            ),
          ),
        ),
      );

      final inkWell = tester.widget<InkWell>(
        find.ancestor(of: find.text('影片详情'), matching: find.byType(InkWell)),
      );

      expect(inkWell.onTap, isNull);
    },
  );

  testWidgets(
    'media preview action tile shows loading indicator and blocks taps',
    (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData,
          home: Scaffold(
            body: MediaPreviewActionGrid(
              actions: [
                MediaPreviewActionItem(
                  label: '相似图片',
                  icon: Icons.image_search_outlined,
                  isLoading: true,
                  onTap: () {
                    tapped = true;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(
        find.ancestor(of: find.text('相似图片'), matching: find.byType(InkWell)),
      );
      await tester.pump();

      expect(tapped, isFalse);
    },
  );
}
