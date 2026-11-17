import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';

part 'actor_mutation_events_provider.g.dart';

/// 演员资料跨页变更广播。
@Riverpod(keepAlive: true)
class ActorMutationEvents extends _$ActorMutationEvents {
  final StreamController<ActorListItemDto> _controller =
      StreamController<ActorListItemDto>.broadcast(sync: true);

  @override
  Stream<ActorListItemDto> build() {
    ref.onDispose(_controller.close);
    return _controller.stream;
  }

  void reportUpdated(ActorListItemDto actor) {
    if (_controller.isClosed) return;
    _controller.add(actor);
  }
}
