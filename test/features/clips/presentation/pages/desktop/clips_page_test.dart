import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/clip_collections/data/dto/clip_collection_dto.dart';
import 'package:sakuramedia/features/clip_collections/presentation/providers/clip_collections_overview_provider.dart';
import 'package:sakuramedia/features/clips/presentation/pages/desktop/clips_page.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_overview_provider.dart';
import 'package:sakuramedia/features/clips/presentation/providers/clips_overview_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_cover_card_skeleton.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_card.dart';

void main() {
  testWidgets('initial loading keeps the desktop clips layout as skeletons', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
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
          theme: sakuraDesktopThemeData,
          home: const Scaffold(body: DesktopClipsPage()),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('clips-collections-skeleton-row')),
      findsOneWidget,
    );
    expect(find.byType(CollectionCardSkeleton), findsWidgets);
    expect(find.byKey(const Key('clips-grid-skeleton')), findsOneWidget);
    expect(find.byType(AppCoverCardSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
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
