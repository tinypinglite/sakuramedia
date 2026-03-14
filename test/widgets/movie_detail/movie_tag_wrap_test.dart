import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_tag_wrap.dart';

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
}
