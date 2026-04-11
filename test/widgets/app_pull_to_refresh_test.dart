import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
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
}
