import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/media/data/media_tag_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_media_item_list.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('selected media shows file tags and manual edit entry', (
    tester,
  ) async {
    var editRequested = false;
    final media = MovieMediaItemDto(
      mediaId: 12,
      libraryId: 1,
      providerKey: 'local',
      playUrl: '/media/12',
      resolution: '3840x2160',
      fileName: 'ABC-001.4k.mkv',
      fileSizeBytes: 1024,
      durationSeconds: 3600,
      valid: true,
      progress: null,
      points: const <MovieMediaPointDto>[],
      tags: const <MediaTagRefDto>[
        MediaTagRefDto(id: 1, name: '4K'),
        MediaTagRefDto(id: 2, name: 'Subtitles'),
      ],
      isMediaTagsManuallyManaged: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        theme: sakuraThemeData,
        home: Scaffold(
          body: MovieMediaItemList(
            mediaItems: [media],
            selectedMediaId: media.mediaId,
            onSelect: (_) {},
            onEditMediaTags: (_) => editRequested = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('movie-media-tags')), findsOneWidget);
    expect(find.text('手工管理'), findsOneWidget);
    expect(find.text('4K'), findsOneWidget);
    expect(find.text('Subtitles'), findsOneWidget);

    await tester.tap(find.byKey(const Key('movie-media-tags-edit-button')));
    expect(editRequested, isTrue);
    expect(tester.takeException(), isNull);
  });
}
