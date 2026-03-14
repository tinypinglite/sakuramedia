import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/paged_actor_summary_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PagedActorSummaryController', () {
    test(
      'initialize loads the first page and exposes pagination state',
      () async {
        final controller = PagedActorSummaryController(
          subscribeActor: ({required actorId}) async {},
          unsubscribeActor: ({required actorId}) async {},
          fetchPage: (page, pageSize) async {
            expect(page, 1);
            expect(pageSize, 24);
            return PaginatedResponseDto<ActorListItemDto>(
              items: _actors(1, 2),
              page: 1,
              pageSize: 24,
              total: 5,
            );
          },
        );

        await controller.initialize();

        expect(controller.items, hasLength(2));
        expect(controller.currentPage, 1);
        expect(controller.total, 5);
        expect(controller.hasLoadedOnce, isTrue);
        expect(controller.hasMore, isTrue);
        expect(controller.initialErrorMessage, isNull);
        expect(controller.loadMoreErrorMessage, isNull);

        controller.dispose();
      },
    );

    test('loadMore appends items until total is exhausted', () async {
      final requestedPages = <int>[];
      final controller = PagedActorSummaryController(
        pageSize: 2,
        subscribeActor: ({required actorId}) async {},
        unsubscribeActor: ({required actorId}) async {},
        fetchPage: (page, pageSize) async {
          requestedPages.add(page);
          if (page == 1) {
            return PaginatedResponseDto<ActorListItemDto>(
              items: _actors(1, 2),
              page: 1,
              pageSize: 2,
              total: 3,
            );
          }
          return PaginatedResponseDto<ActorListItemDto>(
            items: _actors(3, 1),
            page: 2,
            pageSize: 2,
            total: 3,
          );
        },
      );

      await controller.initialize();
      await controller.loadMore();
      await controller.loadMore();

      expect(requestedPages, <int>[1, 2]);
      expect(controller.items, hasLength(3));
      expect(controller.currentPage, 2);
      expect(controller.hasMore, isFalse);

      controller.dispose();
    });

    test(
      'reload resets pagination state and fetches the first page again',
      () async {
        var cycle = 0;
        final controller = PagedActorSummaryController(
          pageSize: 2,
          subscribeActor: ({required actorId}) async {},
          unsubscribeActor: ({required actorId}) async {},
          fetchPage: (page, pageSize) async {
            cycle += 1;
            if (cycle == 1) {
              return PaginatedResponseDto<ActorListItemDto>(
                items: _actors(1, 2),
                page: 1,
                pageSize: 2,
                total: 4,
              );
            }
            return PaginatedResponseDto<ActorListItemDto>(
              items: _actors(101, 1),
              page: 1,
              pageSize: 2,
              total: 1,
            );
          },
        );

        await controller.initialize();
        await controller.reload();

        expect(cycle, 2);
        expect(controller.currentPage, 1);
        expect(controller.total, 1);
        expect(controller.items.single.id, 101);
        expect(controller.hasMore, isFalse);

        controller.dispose();
      },
    );

    test(
      'toggleSubscription unsubscribes actor and updates item in place',
      () async {
        final controller = PagedActorSummaryController(
          subscribeActor: ({required actorId}) async {},
          unsubscribeActor: ({required actorId}) async {
            expect(actorId, 1);
          },
          fetchPage:
              (_, __) async => PaginatedResponseDto<ActorListItemDto>(
                items: <ActorListItemDto>[_actor(1, isSubscribed: true)],
                page: 1,
                pageSize: 24,
                total: 1,
              ),
        );

        await controller.initialize();
        final result = await controller.toggleSubscription(actorId: 1);

        expect(result.status, ActorSubscriptionToggleStatus.unsubscribed);
        expect(controller.items.single.isSubscribed, isFalse);
        expect(controller.isSubscriptionUpdating(1), isFalse);

        controller.dispose();
      },
    );
  });
}

List<ActorListItemDto> _actors(int start, int count) {
  return List<ActorListItemDto>.generate(
    count,
    (index) => ActorListItemDto(
      id: start + index,
      javdbId: 'actor-${start + index}',
      name: 'Actor ${start + index}',
      aliasName: index.isEven ? 'Alias ${start + index}' : '',
      profileImage: null,
      isSubscribed: index.isEven,
    ),
    growable: false,
  );
}

ActorListItemDto _actor(int id, {required bool isSubscribed}) {
  return ActorListItemDto(
    id: id,
    javdbId: 'actor-$id',
    name: 'Actor $id',
    aliasName: '',
    profileImage: null,
    isSubscribed: isSubscribed,
  );
}
