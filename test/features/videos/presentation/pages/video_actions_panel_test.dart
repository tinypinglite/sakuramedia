import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/pages/shared/video_actions_modal.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

import '../../../../support/pump_with_providers.dart';

void main() {
  testWidgets('desktop actions use the dialog and close before delete', (
    tester,
  ) async {
    var deleted = false;
    await pumpWithProviders(
      tester,
      home: _ActionsHost(
        onOpen: (context) => showVideoActions(
          context,
          video: _video(),
          onPlay: () {},
          onDelete: () => deleted = true,
          collections: _collections,
          onCollectionTap: (_) {},
          variant: AppAdaptiveModalVariant.dialog,
        ),
      ),
      theme: buildSakuraDesktopThemeData(),
      physicalSize: const Size(1100, 760),
    );

    await tester.tap(find.byKey(const Key('open-actions')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('desktop-video-actions-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('desktop-video-action-play')), findsOneWidget);

    await tester.tap(find.byKey(const Key('desktop-video-action-delete')));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(find.byKey(const Key('desktop-video-actions-dialog')), findsNothing);
  });

  testWidgets('mobile actions use the sheet and keep a dedicated play button', (
    tester,
  ) async {
    var deleted = false;
    await pumpWithProviders(
      tester,
      home: _ActionsHost(
        onOpen: (context) => showVideoActions(
          context,
          video: _video(),
          onPlay: () {},
          onDelete: () => deleted = true,
          variant: AppAdaptiveModalVariant.drawer,
        ),
      ),
      theme: buildSakuraMobileThemeData(),
      physicalSize: const Size(390, 844),
    );

    await tester.tap(find.byKey(const Key('open-actions')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-video-actions-sheet')), findsOneWidget);
    expect(find.byKey(const Key('mobile-video-action-play')), findsOneWidget);

    await tester.tap(find.byKey(const Key('mobile-video-action-delete')));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(find.byKey(const Key('mobile-video-actions-sheet')), findsNothing);
  });

  testWidgets('collection chips close the panel before navigating', (
    tester,
  ) async {
    var openedCollectionId = 0;
    await pumpWithProviders(
      tester,
      home: _ActionsHost(
        onOpen: (context) => showVideoActions(
          context,
          video: _video(),
          onPlay: () {},
          collections: _collections,
          onCollectionTap: (collection) => openedCollectionId = collection.id,
          variant: AppAdaptiveModalVariant.dialog,
        ),
      ),
      theme: buildSakuraDesktopThemeData(),
      physicalSize: const Size(1100, 760),
    );

    await tester.tap(find.byKey(const Key('open-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('video-collection-chip-7')));
    await tester.pumpAndSettle();

    expect(openedCollectionId, 7);
    expect(find.byKey(const Key('desktop-video-actions-dialog')), findsNothing);
  });
}

const _collections = <VideoCollectionRef>[
  VideoCollectionRef(id: 7, name: 'Collection 7'),
];

VideoItemListItemDto _video() {
  return const VideoItemListItemDto(
    id: 1,
    title: 'Video 1',
    mediaCount: 2,
    canPlay: true,
    collections: _collections,
  );
}

class _ActionsHost extends StatelessWidget {
  const _ActionsHost({required this.onOpen});

  final void Function(BuildContext context) onOpen;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          key: const Key('open-actions'),
          onPressed: () => onOpen(context),
          child: const Text('open'),
        ),
      ),
    );
  }
}
