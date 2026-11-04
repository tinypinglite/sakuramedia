import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_technical_info_dto.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_file_group_card.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_item_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('media card shows interleave first on the technical line', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 760);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        child: MediaListItemCard(
          keyPrefix: 'media',
          item: _item(),
          mobile: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('交错 8.2 MiB · H.264 · 22.8 Mbps · 29.97 fps'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'media card hides the technical line when all fields are missing',
    (tester) async {
      await tester.pumpWidget(
        _app(
          child: MediaListItemCard(
            keyPrefix: 'media',
            item: _item(interleaveGapMib: null, technicalInfo: null),
            mobile: false,
          ),
        ),
      );

      expect(find.byKey(const Key('media-row-tech-1')), findsNothing);
    },
  );

  testWidgets('PornBox media card also shows the technical line', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        child: MediaListItemCard(
          keyPrefix: 'video',
          item: _item(kind: MediaListItemKind.video),
          mobile: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('交错 8.2 MiB · H.264 · 22.8 Mbps · 29.97 fps'),
      findsOneWidget,
    );
  });

  testWidgets('file group card shows the same technical line', (tester) async {
    await tester.pumpWidget(
      _app(
        child: MediaFileGroupCard(
          items: <MediaListItemDto>[
            _item(),
            _item(id: 2, interleaveGapMib: null, technicalInfo: null),
          ],
          countLabel: '2 个版本',
          headerKey: const Key('group-header'),
          deleteLabel: '删除',
          keyPrefix: 'group',
          mobile: false,
          onDelete: (_) {},
          selectedIds: null,
          onToggle: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('交错 8.2 MiB · H.264 · 22.8 Mbps · 29.97 fps'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('group-file-tech-1')), findsOneWidget);
    expect(find.byKey(const Key('group-file-tech-2')), findsNothing);
  });
}

MediaListItemDto _item({
  int id = 1,
  double? interleaveGapMib = 8.2,
  MediaListItemKind kind = MediaListItemKind.jav,
  MediaTechnicalInfoDto? technicalInfo = const MediaTechnicalInfoDto(
    codecName: 'h264',
    videoBitRate: 22793091,
    containerBitRate: 10000000,
    frameRate: 29.97,
  ),
}) {
  return MediaListItemDto(
    id: id,
    kind: kind,
    movieNumber: kind == MediaListItemKind.jav ? 'ABC-$id' : null,
    title: kind == MediaListItemKind.jav ? 'Movie $id' : 'Video $id',
    fileName: 'ABC-$id.mp4',
    fileSizeBytes: 2147483648,
    durationSeconds: 3661,
    resolution: '1920x1080',
    interleaveGapMib: interleaveGapMib,
    technicalInfo: technicalInfo,
    valid: true,
    createdAt: DateTime(2026, 11, 5),
    updatedAt: DateTime(2026, 11, 5),
  );
}

Widget _app({required Widget child}) {
  return ProviderScope(
    overrides: [mediaLibrariesProvider.overrideWith(_FakeMediaLibraries.new)],
    child: MaterialApp(
      theme: sakuraMobileThemeData,
      locale: const Locale('zh'),
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    ),
  );
}

class _FakeMediaLibraries extends MediaLibraries {
  @override
  Future<MediaLibrariesState> build() async => MediaLibrariesState.empty;
}
