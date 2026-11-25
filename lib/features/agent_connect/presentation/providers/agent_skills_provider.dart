import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/features/agent_connect/data/agent_skill_dto.dart';
import 'package:sakuramedia/features/agent_connect/data/agent_skills_api.dart';

final agentSkillsApiProvider = Provider<AgentSkillsApi>((ref) {
  return AgentSkillsApi(ref.watch(apiClientProvider));
});

final agentSkillsCatalogProvider =
    FutureProvider.autoDispose<AgentSkillsCatalogDto>((ref) {
      return ref.watch(agentSkillsApiProvider).getCatalog();
    });
