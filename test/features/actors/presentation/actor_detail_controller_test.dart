import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/actor_detail_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ActorDetailController', () {
    test('refresh updates actor detail after initial load', () async {
      var cycle = 0;
      final controller = ActorDetailController(
        actorId: 1,
        fetchActorDetail: ({required actorId}) async {
          cycle += 1;
          return _actor(cycle == 1 ? 'Old actor' : 'New actor');
        },
      );

      await controller.load();
      await controller.refresh();

      expect(controller.actor?.name, 'New actor');
      expect(controller.errorMessage, isNull);
    });

    test('refresh rethrows and keeps existing actor on failure', () async {
      var cycle = 0;
      final controller = ActorDetailController(
        actorId: 1,
        fetchActorDetail: ({required actorId}) async {
          cycle += 1;
          if (cycle == 1) {
            return _actor('Old actor');
          }
          throw Exception('refresh failed');
        },
      );

      await controller.load();

      await expectLater(controller.refresh(), throwsException);

      expect(controller.actor?.name, 'Old actor');
      expect(controller.errorMessage, isNull);
    });
  });
}

ActorListItemDto _actor(String name) {
  return ActorListItemDto(
    id: 1,
    javdbId: 'actor-1',
    name: name,
    aliasName: '',
    profileImage: null,
    isSubscribed: false,
  );
}
