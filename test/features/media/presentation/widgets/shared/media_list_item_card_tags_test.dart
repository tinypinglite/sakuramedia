import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_tag_dto.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_item_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('JAV media card shows tags and opens the tag editor', (
    tester,
  ) async {
    var editRequested = false;
    final item = MediaListItemDto(
      id: 42,
      kind: MediaListItemKind.jav,
      movieNumber: 'ABC-001',
      title: 'Example',
      fileName: 'ABC-001.4k.mkv',
      fileSizeBytes: 1024,
      durationSeconds: 60,
      resolution: '3840x2160',
      valid: true,
      createdAt: DateTime(2026, 10, 31),
      updatedAt: DateTime(2026, 10, 31),
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
          body: MediaListItemCard(
            keyPrefix: 'test-media',
            item: item,
            mobile: false,
            onEditTags: () => editRequested = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4K'), findsOneWidget);
    expect(find.text('Subtitles'), findsOneWidget);
    expect(find.text('手工'), findsOneWidget);

    await tester.tap(find.byKey(const Key('test-media-edit-tags-42')));
    expect(editRequested, isTrue);
    expect(tester.takeException(), isNull);
  });
}
