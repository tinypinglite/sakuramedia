import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';
import 'package:sakuramedia/features/subscriptions/presentation/movie_subscription_filter_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/widgets/movie_subscription_filter_sections.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_popover.dart';

import '../../../support/pump_with_providers.dart';

void main() {
  testWidgets('subscription drawer reset keeps status and sort', (
    tester,
  ) async {
    const current = MovieSubscriptionFilterState(
      status: MovieSubscriptionStatus.imported,
      sort: MovieSubscriptionSort.releaseDateAsc,
      search: 'abc',
    );
    MovieSubscriptionFilterState? changed;

    await pumpWithProviders(
      tester,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const Key('open-subscription-filter'),
              onPressed: () => showAppBottomDrawer<void>(
                context: context,
                drawerKey: const Key('subscription-filter-drawer'),
                maxHeightFactor: 0.6,
                builder: (_) =>
                    AppMobileFilterDrawer<MovieSubscriptionFilterState>(
                      current: current,
                      initial: current.resetPanel(),
                      isDefault: (value) => value.isPanelDefault,
                      onChanged: (value) => changed = value,
                      scrollViewKey: const Key('subscription-filter-scroll'),
                      contentBuilder: (context, local, onApply) =>
                          MovieSubscriptionFilterSectionGroup(
                            filterState: local,
                            onChanged: onApply,
                          ),
                    ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
      theme: buildSakuraMobileThemeData(),
      physicalSize: const Size(390, 844),
    );

    await tester.tap(find.byKey(const Key('open-subscription-filter')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('subscription-filter-drawer')), findsOneWidget);

    await tester.tap(find.byType(AppGlassResetButton));
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.status, MovieSubscriptionStatus.imported);
    expect(changed!.sort, MovieSubscriptionSort.releaseDateAsc);
    expect(changed!.search, isEmpty);
    expect(find.byKey(const Key('subscription-filter-drawer')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
