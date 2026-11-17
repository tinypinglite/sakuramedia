import 'package:sakuramedia/core/json/json_parse.dart';

class ActorCandidateDto {
  const ActorCandidateDto({
    required this.candidateId,
    required this.name,
    required this.aliasNames,
    required this.avatarUrl,
    required this.existingActorId,
  });

  final String candidateId;
  final String name;
  final List<String> aliasNames;
  final String? avatarUrl;
  final int? existingActorId;

  ActorCandidateDto copyWith({int? existingActorId}) {
    return ActorCandidateDto(
      candidateId: candidateId,
      name: name,
      aliasNames: aliasNames,
      avatarUrl: avatarUrl,
      existingActorId: existingActorId ?? this.existingActorId,
    );
  }

  factory ActorCandidateDto.fromJson(Map<String, dynamic> json) {
    final rawAliases = json['alias_names'] ?? json['aliases'];
    return ActorCandidateDto(
      candidateId: asStringOrNull(json['candidate_id'], trim: true) ?? '',
      name: asStringOrNull(json['name'], trim: true) ?? '',
      aliasNames: rawAliases is List
          ? rawAliases
                .map((item) => asStringOrNull(item, trim: true))
                .whereType<String>()
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      avatarUrl: asStringOrNull(json['avatar_url'], trim: true),
      existingActorId: asIntOrNull(json['existing_actor_id']),
    );
  }
}
