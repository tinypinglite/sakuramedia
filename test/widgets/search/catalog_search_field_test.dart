import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/search/catalog_search_field.dart';

void main() {
  test(
    'catalog search field uses theme tokens instead of hardcoded colors',
    () {
      final source =
          File(
            'lib/widgets/search/catalog_search_field.dart',
          ).readAsStringSync();

      expect(source, contains('context.appColors'));
      expect(source, contains('context.appSpacing'));
      expect(source, contains('context.appRadius'));
      expect(source, isNot(contains('Color(0x')));
    },
  );

  testWidgets('catalog search field renders a single search icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Material(
          child: CatalogSearchField(
            controller: TextEditingController(),
            hintText: '找影片',
            onSearchTap: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.public_rounded), findsNothing);

    final iconTheme = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.byIcon(Icons.search_rounded),
            matching: find.byType(IconTheme),
          )
          .first,
    );
    expect(iconTheme.data.size, AppComponentTokens.defaults().iconSizeMd);
  });

  testWidgets('catalog search field renders online toggle when enabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Material(
          child: CatalogSearchField(
            controller: TextEditingController(),
            hintText: '找影片',
            showOnlineToggle: true,
            isOnlineSearchEnabled: false,
            onOnlineSearchToggle: (_) {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.public_rounded), findsOneWidget);
  });

  testWidgets('catalog search field renders image search icon when enabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Material(
          child: CatalogSearchField(
            controller: TextEditingController(),
            hintText: '找影片',
            showImageSearchButton: true,
            onImageSearchTap: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.image_search_outlined), findsOneWidget);
  });

  testWidgets('catalog search field triggers image search callback on tap', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Material(
          child: CatalogSearchField(
            controller: TextEditingController(),
            hintText: '找影片',
            showImageSearchButton: true,
            onImageSearchTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.image_search_outlined));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('catalog search field toggles online search state on tap', (
    WidgetTester tester,
  ) async {
    bool? latestValue;

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Material(
          child: CatalogSearchField(
            controller: TextEditingController(),
            hintText: '找影片',
            showOnlineToggle: true,
            isOnlineSearchEnabled: false,
            onOnlineSearchToggle: (value) => latestValue = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.public_rounded));
    await tester.pump();

    expect(latestValue, isTrue);
  });

  testWidgets('catalog search field submits on icon tap', (
    WidgetTester tester,
  ) async {
    var submitCount = 0;
    final controller = TextEditingController(text: 'abp123');

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Material(
          child: CatalogSearchField(
            controller: controller,
            hintText: '找影片',
            onSearchTap: () => submitCount++,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pump();

    expect(submitCount, 1);
  });

  testWidgets('catalog search field submits current text on keyboard action', (
    WidgetTester tester,
  ) async {
    String? latestValue;

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Material(
          child: CatalogSearchField(
            controller: TextEditingController(),
            hintText: '找影片',
            onSubmitted: (value) => latestValue = value,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'mikami');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(latestValue, 'mikami');
  });
}
