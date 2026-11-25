import 'package:sakuramedia/features/agent_connect/data/agent_skill_dto.dart';

/// Prompt text handed to the agent. English only on purpose: it is machine
/// instruction, not UI copy, and one canonical language avoids drift.
String buildAgentConnectionText({
  required String baseUrl,
  required String apiKey,
  required List<AgentSkillDto> skills,
}) {
  final skillLines = skills
      .map(
        (skill) =>
            '- ${skill.name}@${skill.version}\n'
            '  ${skill.downloadUrl}',
      )
      .join('\n');
  return 'Install or update the following Sakuramedia skills.\n\n'
      '$skillLines\n\n'
      'More Sakuramedia skills will follow. They all use the same server and the '
      'same API key, so share one connection across the series instead of asking '
      'the user again for each skill.\n\n'
      'If a skill with the same name is already installed, do not skip it: '
      'overwrite it with the specified version and keep its config and data '
      'directory intact. Report the actual version and install path of each '
      'skill when done.\n\n'
      'Connection:\n'
      'SAKURAMEDIA_BASE_URL=$baseUrl\n'
      'SAKURAMEDIA_API_KEY=$apiKey\n';
}
