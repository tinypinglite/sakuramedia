import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/agent_connect/data/agent_skill_dto.dart';

void main() {
  group('AgentSkillsCatalogDto', () {
    test('parses the market skills index shape', () {
      final catalog = AgentSkillsCatalogDto.fromJson(<String, dynamic>{
        'schema_version': 1,
        'updated_at': '2026-11-26T11:44:23Z',
        'skills': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'sakuramedia-acquire',
            'author': 'SakuraMedia',
            'official': true,
            'display_name': '补片',
            'display_name_en': 'Acquire',
            'description': '查片',
            'description_en': 'Find a movie',
            'version': '0.1.0',
            'download_url': 'https://example.com/sakuramedia-acquire-0.1.0.zip',
            'sha256': 'a' * 64,
          },
        ],
      });

      expect(catalog.skills, hasLength(1));
      final skill = catalog.skills.single;
      expect(skill.name, 'sakuramedia-acquire');
      expect(skill.author, 'SakuraMedia');
      expect(skill.displayNameFor(true), '补片');
      expect(skill.displayNameFor(false), 'Acquire');
      expect(skill.descriptionFor(true), '查片');
      expect(skill.descriptionFor(false), 'Find a movie');
      expect(skill.version, '0.1.0');
    });

    test('drops entries without name or download url', () {
      final catalog = AgentSkillsCatalogDto.fromJson(<String, dynamic>{
        'skills': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'no-url'},
          <String, dynamic>{'download_url': 'https://example.com/x.zip'},
        ],
      });

      expect(catalog.skills, isEmpty);
    });

    test('falls back to the other language and then to name', () {
      const skill = AgentSkillDto(
        name: 'community-skill',
        author: 'someone',
        displayName: '',
        displayNameEn: 'Community Skill',
        version: '1.0.0',
        description: '',
        descriptionEn: '',
        downloadUrl: 'https://example.com/c.zip',
      );

      expect(skill.displayNameFor(true), 'Community Skill');
      expect(skill.descriptionFor(true), isEmpty);
    });
  });
}
