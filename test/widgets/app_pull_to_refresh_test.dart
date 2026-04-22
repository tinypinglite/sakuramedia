import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/app_pull_to_refresh.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('uses cupertino activity indicator on iOS', (
    WidgetTester tester,
  ) async {
    final completer = Completer<void>();
    addTearDown(() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData.copyWith(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: AppPullToRefresh(
            onRefresh: () => completer.future,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const <Widget>[SizedBox(height: 120, child: Text('A'))],
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
  });

  testWidgets('uses material progress indicator on android', (
    WidgetTester tester,
  ) async {
    final completer = Completer<void>();
    addTearDown(() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData.copyWith(platform: TargetPlatform.android),
        home: Scaffold(
          body: AppPullToRefresh(
            onRefresh: () => completer.future,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const <Widget>[SizedBox(height: 120, child: Text('A'))],
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();

    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
  });

  testWidgets(
    'adaptive refresh scroll view uses cupertino sliver refresh on iOS',
    (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var refreshCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData.copyWith(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: AppAdaptiveRefreshScrollView(
              onRefresh: () async {
                refreshCount += 1;
              },
              slivers: const <Widget>[
                SliverToBoxAdapter(
                  child: SizedBox(height: 120, child: Text('A')),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pump();

      expect(refreshCount, 1);
      expect(find.byType(RefreshIndicator), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'adaptive refresh scroll view keeps material refresh wrapper on android',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: sakuraThemeData.copyWith(platform: TargetPlatform.android),
          home: Scaffold(
            body: AppAdaptiveRefreshScrollView(
              onRefresh: () async {},
              slivers: const <Widget>[
                SliverToBoxAdapter(
                  child: SizedBox(height: 120, child: Text('A')),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byType(CupertinoSliverRefreshControl), findsNothing);
    },
  );
}
