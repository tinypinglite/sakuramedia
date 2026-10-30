import 'package:sakuramedia/core/json/json_parse.dart';

class MediaTagRefDto {
  const MediaTagRefDto({required this.id, required this.name});

  final int id;
  final String name;

  factory MediaTagRefDto.fromJson(Map<String, dynamic> json) {
    return MediaTagRefDto(
      id: asInt(json['id']),
      name: asStringOrNull(json['name'], trim: true) ?? '',
    );
  }
}

class MediaTagDto {
  const MediaTagDto({
    required this.id,
    required this.name,
    required this.includeTerms,
    required this.excludeTerms,
    required this.enabled,
    required this.mediaCount,
  });

  final int id;
  final String name;
  final List<String> includeTerms;
  final List<String> excludeTerms;
  final bool enabled;
  final int mediaCount;

  MediaTagRefDto get ref => MediaTagRefDto(id: id, name: name);

  factory MediaTagDto.fromJson(Map<String, dynamic> json) {
    return MediaTagDto(
      id: asInt(json['id']),
      name: asStringOrNull(json['name'], trim: true) ?? '',
      includeTerms: _stringList(json['include_terms']),
      excludeTerms: _stringList(json['exclude_terms']),
      enabled: json['enabled'] as bool? ?? true,
      mediaCount: asInt(json['media_count']),
    );
  }
}

class MediaTagUpsertPayload {
  const MediaTagUpsertPayload({
    required this.name,
    required this.includeTerms,
    required this.excludeTerms,
    required this.enabled,
  });

  final String name;
  final List<String> includeTerms;
  final List<String> excludeTerms;
  final bool enabled;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name.trim(),
      'include_terms': includeTerms,
      'exclude_terms': excludeTerms,
      'enabled': enabled,
    };
  }
}

class MediaTagPreviewMatchDto {
  const MediaTagPreviewMatchDto({
    required this.tagId,
    required this.name,
    required this.matchedTerm,
  });

  final int tagId;
  final String name;
  final String matchedTerm;

  factory MediaTagPreviewMatchDto.fromJson(Map<String, dynamic> json) {
    return MediaTagPreviewMatchDto(
      tagId: asInt(json['tag_id']),
      name: asStringOrNull(json['name'], trim: true) ?? '',
      matchedTerm: asStringOrNull(json['matched_term'], trim: true) ?? '',
    );
  }
}

class MediaTagAssignmentDto {
  const MediaTagAssignmentDto({
    required this.mediaId,
    required this.tags,
    required this.isManuallyManaged,
  });

  final int mediaId;
  final List<MediaTagRefDto> tags;
  final bool isManuallyManaged;

  factory MediaTagAssignmentDto.fromJson(Map<String, dynamic> json) {
    return MediaTagAssignmentDto(
      mediaId: asInt(json['media_id']),
      tags: _objectList(json['tags'], (item) => MediaTagRefDto.fromJson(item)),
      isManuallyManaged:
          json['is_media_tags_manually_managed'] as bool? ?? false,
    );
  }
}

List<MediaTagRefDto> mediaTagRefsFromJson(dynamic value) {
  return _objectList(value, MediaTagRefDto.fromJson);
}

List<String> _stringList(dynamic value) {
  return List<String>.unmodifiable(asStringList(value, trim: true));
}

List<T> _objectList<T>(dynamic value, T Function(Map<String, dynamic>) parse) {
  return List<T>.unmodifiable(
    (value is List ? value : const <dynamic>[])
        .map(asMapOrNull)
        .whereType<Map<String, dynamic>>()
        .map(parse),
  );
}
