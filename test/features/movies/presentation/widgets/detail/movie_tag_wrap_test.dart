import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_tag_wrap.dart';

void main() {
  testWidgets('movie tag wrap renders tags as shared pills', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: MovieTagWrap(
            tags: const <MovieTagDto>[
              MovieTagDto(tagId: 1, name: '单体作品'),
              MovieTagDto(tagId: 2, name: '中出'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('单体作品'), findsOneWidget);
    expect(find.text('中出'), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('movie tag wrap shows empty message when tags are empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: const Scaffold(body: MovieTagWrap(tags: <MovieTagDto>[])),
      ),
    );

    expect(find.text('暂无标签'), findsOneWidget);
  });

  testWidgets('movie tag wrap invokes onTagTap with the tapped tag', (
    WidgetTester tester,
  ) async {
    MovieTagDto? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: MovieTagWrap(
            tags: const <MovieTagDto>[
              MovieTagDto(tagId: 5, name: '巨乳'),
              MovieTagDto(tagId: 8, name: '单体作品'),
            ],
            onTagTap: (tag) => tapped = tag,
          ),
        ),
      ),
    );

    // 提供 onTagTap 后标签变为可点击。
    expect(find.byType(InkWell), findsNWidgets(2));

    await tester.tap(find.text('巨乳'));
    await tester.pump();

    expect(tapped, isNotNull);
    expect(tapped!.tagId, 5);
    expect(tapped!.name, '巨乳');
  });
}
