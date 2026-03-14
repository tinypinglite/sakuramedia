class AccountDto {
  const AccountDto({
    required this.username,
    required this.createdAt,
    required this.lastLoginAt,
  });

  final String username;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  factory AccountDto.fromJson(Map<String, dynamic> json) {
    return AccountDto(
      username: json['username'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      lastLoginAt: DateTime.tryParse(json['last_login_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'username': username,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      if (lastLoginAt != null)
        'last_login_at': lastLoginAt!.toUtc().toIso8601String(),
    };
  }
}
