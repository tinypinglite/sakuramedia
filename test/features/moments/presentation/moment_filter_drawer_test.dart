import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/moments/presentation/moment_filter_sections.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_popover.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets(
    'moments drawer applies changes instantly without a reset footer',
    (tester) async {
      MomentKindFilter? selectedKind;
      MomentSortOrder? selectedSort;

      await pumpWithProviders(
        tester,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                key: const Key('open-moments-filter'),
                onPressed: () => showMobileMomentFilterDrawer(
                  context,
                  kindFilter: MomentKindFilter.jav,
                  sortOrder: MomentSortOrder.latest,
                  onKindChanged: (value) => selectedKind = value,
                  onSortChanged: (value) => selectedSort = value,
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
        theme: buildSakuraMobileThemeData(),
        physicalSize: const Size(390, 844),
      );

      await tester.tap(find.byKey(const Key('open-moments-filter')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mobile-moments-filter-drawer')),
        findsOneWidget,
      );
      expect(find.byType(AppGlassFilterFooter), findsNothing);

      await tester.tap(find.text('视频'));
      await tester.pumpAndSettle();
      expect(selectedKind, MomentKindFilter.video);
      expect(
        find.byKey(const Key('mobile-moments-filter-drawer')),
        findsOneWidget,
      );

      await tester.tap(find.text('最早'));
      await tester.pumpAndSettle();
      expect(selectedSort, MomentSortOrder.earliest);
      expect(
        find.byKey(const Key('mobile-moments-filter-drawer')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
