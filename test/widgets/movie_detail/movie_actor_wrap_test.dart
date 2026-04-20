import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/movie_detail/movie_actor_wrap.dart';

void main() {
  testWidgets('movie actor wrap uses airy actor spacing within the section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Scaffold(
          body: MovieActorWrap(
            actors: const <MovieActorDto>[
              MovieActorDto(
                id: 1,
                javdbId: 'actor-1',
                name: '演员一',
                aliasName: '演员一',
                gender: MovieActorDto.femaleGender,
                isSubscribed: false,
                profileImage: null,
              ),
              MovieActorDto(
                id: 2,
                javdbId: 'actor-2',
                name: '演员二',
                aliasName: '演员二',
                gender: 0,
                isSubscribed: false,
                profileImage: null,
              ),
            ],
          ),
        ),
      ),
    );

    final wrap = tester.widget<Wrap>(find.byType(Wrap));
    final verticalGaps = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .map((box) => box.height)
        .toList();

    expect(wrap.spacing, sakuraThemeData.appSpacing.sm);
    expect(wrap.runSpacing, sakuraThemeData.appSpacing.sm);
    expect(
      verticalGaps.whereType<double>(),
      contains(sakuraThemeData.appSpacing.sm),
    );
  });
}
