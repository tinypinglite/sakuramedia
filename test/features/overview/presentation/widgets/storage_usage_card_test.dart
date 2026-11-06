import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/storage_usage_card.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('storage usage list scrolls when libraries exceed the cap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildSakuraDesktopThemeData(),
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 480,
              child: StorageUsageCard(
                libraries: List<MediaLibraryUsageDto>.generate(
                  10,
                  (index) => MediaLibraryUsageDto(
                    libraryId: index + 1,
                    name: 'Library ${index + 1}',
                    providerKey: 'local',
                    fileCount: 1000 + index,
                    totalSizeBytes: (index + 1) * 1024 * 1024 * 1024,
                  ),
                  growable: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstRow = find.byKey(const Key('overview-storage-library-1'));
    final before = tester.getTopLeft(firstRow).dy;
    await tester.drag(
      find.byKey(const Key('overview-storage-usage-scroll')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(firstRow).dy;

    expect(after, lessThan(before));
    expect(tester.takeException(), isNull);
  });
}
