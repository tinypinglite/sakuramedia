import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_filter_options_dto.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';

@immutable
class ActorFilterOptionsScope {
  const ActorFilterOptionsScope({
    required this.subscriptionStatus,
    required this.gender,
  });

  final ActorSubscriptionStatus subscriptionStatus;
  final ActorGender gender;

  @override
  bool operator ==(Object other) =>
      other is ActorFilterOptionsScope &&
      other.subscriptionStatus == subscriptionStatus &&
      other.gender == gender;

  @override
  int get hashCode => Object.hash(subscriptionStatus, gender);
}

final actorFilterOptionsProvider = FutureProvider.autoDispose
    .family<ActorFilterOptionsDto, ActorFilterOptionsScope>((ref, scope) {
      return ref
          .watch(actorsApiProvider)
          .getActorFilterOptions(
            subscriptionStatus: scope.subscriptionStatus,
            gender: scope.gender,
          );
    });
