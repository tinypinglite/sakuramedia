import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/agent_connect/data/agent_connection_text.dart';
import 'package:sakuramedia/features/agent_connect/data/agent_skill_dto.dart';

void main() {
  group('buildAgentConnectionText', () {
    test(
      'writes an English prompt that shares one connection across the series',
      () {
        final text = buildAgentConnectionText(
          baseUrl: 'http://192.168.2.10:8000',
          apiKey: 'sk-AbCd1234',
          skills: const <AgentSkillDto>[
            AgentSkillDto(
              name: 'sakuramedia-acquire',
              author: 'SakuraMedia',
              displayName: '补片',
              displayNameEn: 'Acquire',
              version: '0.1.0',
              description: '查片',
              descriptionEn: 'Find a movie',
              downloadUrl: 'https://example.com/acquire.zip',
            ),
          ],
        );

        expect(
          text,
          contains('Install or update the following Sakuramedia skills.'),
        );
        expect(text, contains('More Sakuramedia skills will follow.'));
        expect(text, contains('share one connection across the series'));
        expect(text, contains('- sakuramedia-acquire@0.1.0'));
        expect(text, contains('  https://example.com/acquire.zip'));
        expect(text, contains('SAKURAMEDIA_BASE_URL=http://192.168.2.10:8000'));
        expect(text, contains('SAKURAMEDIA_API_KEY=sk-AbCd1234'));
        expect(RegExp(r'[\u4e00-\u9fff]').hasMatch(text), isFalse);
      },
    );
  });
}
