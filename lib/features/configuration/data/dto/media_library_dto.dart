import 'package:sakuramedia/core/json/json_parse.dart';

/// 媒体库实例。
///
/// Provider 的实现和配置对前端保持不透明；可编辑字段由 Provider 目录
/// (`GET /media-libraries/providers`) 驱动。
class MediaLibraryDto {
  const MediaLibraryDto({
    required this.id,
    required this.name,
    required this.providerKey,
    this.providerConfig = const <String, dynamic>{},
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String providerKey;
  final Map<String, dynamic> providerConfig;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory MediaLibraryDto.fromJson(Map<String, dynamic> json) {
    final rawConfig = json['provider_config'];
    final config = rawConfig is Map
        ? rawConfig.map(
            (dynamic key, dynamic value) => MapEntry(key.toString(), value),
          )
        : <String, dynamic>{};
    final providerKey = json['provider_key'];
    if (providerKey is! String || providerKey.trim().isEmpty) {
      throw const FormatException(
        'media_library.provider_key must be a non-empty string',
      );
    }
    return MediaLibraryDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      providerKey: providerKey,
      providerConfig: Map<String, dynamic>.unmodifiable(config),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }
}

class CreateMediaLibraryPayload {
  const CreateMediaLibraryPayload({
    required this.name,
    required this.providerKey,
    this.providerConfig = const <String, dynamic>{},
  });

  final String name;
  final String providerKey;
  final Map<String, dynamic> providerConfig;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'provider_key': providerKey,
      'provider_config': providerConfig,
    };
  }
}

class UpdateMediaLibraryPayload {
  const UpdateMediaLibraryPayload({this.name, this.providerConfig});

  final String? name;
  final Map<String, dynamic>? providerConfig;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (name != null) 'name': name,
      if (providerConfig != null) 'provider_config': providerConfig,
    };
  }
}
