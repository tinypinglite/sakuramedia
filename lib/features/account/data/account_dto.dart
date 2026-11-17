class AccountDto {
  const AccountDto({
    required this.username,
    required this.createdAt,
    required this.lastLoginAt,
    this.language,
  });

  final String username;
  final String? language;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  factory AccountDto.fromJson(Map<String, dynamic> json) {
    return AccountDto(
      username: json['username'] as String? ?? '',
      language: json['language'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      lastLoginAt: DateTime.tryParse(json['last_login_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'username': username,
      if (language != null) 'language': language,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (lastLoginAt != null)
        'last_login_at': lastLoginAt!.toUtc().toIso8601String(),
    };
  }
}

/// API 密钥条目（不含明文）。
class ApiKeyDto {
  const ApiKeyDto({
    required this.id,
    required this.name,
    required this.keyHint,
    this.createdAt,
    this.lastUsedAt,
  });

  final int id;
  final String name;
  final String keyHint;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;

  factory ApiKeyDto.fromJson(Map<String, dynamic> json) {
    return ApiKeyDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      keyHint: json['key_hint'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      lastUsedAt: DateTime.tryParse(json['last_used_at'] as String? ?? ''),
    );
  }
}

/// 生成响应：key 明文仅此一次返回。
class ApiKeyCreatedDto extends ApiKeyDto {
  const ApiKeyCreatedDto({
    required super.id,
    required super.name,
    required super.keyHint,
    super.createdAt,
    super.lastUsedAt,
    required this.key,
  });

  final String key;

  factory ApiKeyCreatedDto.fromJson(Map<String, dynamic> json) {
    final base = ApiKeyDto.fromJson(json);
    return ApiKeyCreatedDto(
      id: base.id,
      name: base.name,
      keyHint: base.keyHint,
      createdAt: base.createdAt,
      lastUsedAt: base.lastUsedAt,
      key: json['key'] as String? ?? '',
    );
  }
}
