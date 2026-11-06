import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';

@immutable
class ActorDetailState {
  const ActorDetailState({this.actor, this.errorMessage});

  final ActorDetailDto? actor;
  final String? errorMessage;
}
