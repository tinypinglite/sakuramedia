import 'dart:convert';

import 'package:sakuramedia/config/app_agent_skills.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/agent_connect/data/agent_skill_dto.dart';

class AgentSkillsApi {
  const AgentSkillsApi(this._apiClient);

  final ApiClient _apiClient;

  Future<AgentSkillsCatalogDto> getCatalog() async {
    final raw = await _apiClient.getText(
      AppAgentSkills.catalogUrl,
      requiresAuth: false,
      receiveTimeout: const Duration(seconds: 15),
    );
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid agent skills catalog');
    }
    return AgentSkillsCatalogDto.fromJson(decoded);
  }
}
