import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_overview_provider.dart';
import 'package:sakuramedia/features/clips/presentation/pages/mobile/overview_clips_tab.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_overview_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_overview_state.dart';
import 'package:sakuramedia/theme.dart';

void main() {
  testWidgets('initial loading uses collection and clip grid skeletons', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipsOverviewProvider.overrideWith(_LoadingClipsOverview.new),
          clipCollectionsOverviewProvider.overrideWith(
            _LoadingClipCollectionsOverview.new,
          ),
        ],
        child: MaterialApp(
          theme: sakuraMobileThemeData,
          home: const Scaffold(body: MobileOverviewClipsTab()),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('mobile-clips-collections-skeleton-row')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mobile-clips-grid-skeleton')), findsOneWidget);
    expect(find.byKey(const Key('mobile-clips-loading')), findsNothing);
  });
}

class _LoadingClipsOverview extends ClipsOverview {
  @override
  Future<ClipsOverviewState> build() => Completer<ClipsOverviewState>().future;
}

class _LoadingClipCollectionsOverview extends ClipCollectionsOverview {
  @override
  Future<List<ClipCollectionDto>> build() =>
      Completer<List<ClipCollectionDto>>().future;
}
