class AgentSkillDto {
  const AgentSkillDto({
    required this.name,
    required this.author,
    required this.displayName,
    required this.displayNameEn,
    required this.version,
    required this.description,
    required this.descriptionEn,
    required this.downloadUrl,
  });

  final String name;
  final String author;
  final String displayName;
  final String displayNameEn;
  final String version;
  final String description;
  final String descriptionEn;
  final String downloadUrl;

  String displayNameFor(bool chinese) {
    final preferred = chinese ? displayName : displayNameEn;
    if (preferred.isNotEmpty) {
      return preferred;
    }
    final fallback = chinese ? displayNameEn : displayName;
    return fallback.isNotEmpty ? fallback : name;
  }

  String descriptionFor(bool chinese) {
    final preferred = chinese ? description : descriptionEn;
    return preferred.isNotEmpty
        ? preferred
        : (chinese ? descriptionEn : description);
  }

  factory AgentSkillDto.fromJson(Map<String, dynamic> json) {
    return AgentSkillDto(
      name: json['name'] as String? ?? '',
      author: json['author'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      displayNameEn: json['display_name_en'] as String? ?? '',
      version: json['version'] as String? ?? '',
      description: json['description'] as String? ?? '',
      descriptionEn: json['description_en'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
    );
  }
}

class AgentSkillsCatalogDto {
  const AgentSkillsCatalogDto({required this.skills});

  final List<AgentSkillDto> skills;

  factory AgentSkillsCatalogDto.fromJson(Map<String, dynamic> json) {
    final rawSkills = json['skills'];
    if (rawSkills is! List) {
      return const AgentSkillsCatalogDto(skills: []);
    }
    return AgentSkillsCatalogDto(
      skills: rawSkills
          .whereType<Map>()
          .map(
            (item) => AgentSkillDto.fromJson(Map<String, dynamic>.from(item)),
          )
          .where(
            (skill) => skill.name.isNotEmpty && skill.downloadUrl.isNotEmpty,
          )
          .toList(growable: false),
    );
  }
}
