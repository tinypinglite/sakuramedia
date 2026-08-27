/// Provider 目录返回的配置字段类型。
enum ProviderConfigFieldInput { text, secret, path }

extension ProviderConfigFieldInputX on ProviderConfigFieldInput {
  static ProviderConfigFieldInput fromWire(
    Object? value, {
    String path = 'input',
  }) {
    return switch (value) {
      'text' => ProviderConfigFieldInput.text,
      'secret' => ProviderConfigFieldInput.secret,
      'path' => ProviderConfigFieldInput.path,
      _ => throw FormatException('$path must be one of text, secret, path'),
    };
  }
}

/// Provider 目录中一个可配置字段的元数据。
///
/// 目录协议目前只支持文本、敏感文本和路径三种输入；不要在这里推断
/// JSON Schema、默认值或选项。Provider 配置本身仍由后端保持不透明。
class ProviderConfigFieldDto {
  const ProviderConfigFieldDto({
    required this.key,
    required this.label,
    required this.input,
    required this.required,
    required this.multiline,
    required this.readOnly,
    this.description,
    required this.hint,
  });

  final String key;
  final String label;
  final ProviderConfigFieldInput input;
  final bool required;
  final bool multiline;
  final bool readOnly;
  final String? description;
  final String? hint;

  bool get isSecret => input == ProviderConfigFieldInput.secret;

  factory ProviderConfigFieldDto.fromJson(
    Map<String, dynamic> json, {
    String path = 'provider config field',
  }) {
    return ProviderConfigFieldDto(
      key: _requiredString(json, 'key', path: path),
      label: _requiredString(json, 'label', path: path),
      input: ProviderConfigFieldInputX.fromWire(
        json['input'],
        path: '$path.input',
      ),
      required: _requiredBool(json, 'required', path: path),
      multiline: _requiredBool(json, 'multiline', path: path),
      readOnly: _requiredBool(json, 'read_only', path: path),
      description: _optionalString(json, 'description', path: path),
      hint: _optionalString(json, 'hint', path: path),
    );
  }
}

/// `GET /media-libraries/providers` 的一个 Provider Bundle。
class MediaProviderDto {
  const MediaProviderDto({
    required this.providerKey,
    required this.displayName,
    required this.libraryConfigFields,
    required this.downloadConfigFields,
  });

  final String providerKey;
  final String displayName;
  final List<ProviderConfigFieldDto> libraryConfigFields;

  /// `null` 表示该 Provider 不支持下载，空列表表示支持下载但无需配置。
  final List<ProviderConfigFieldDto>? downloadConfigFields;

  bool get supportsDownloads => downloadConfigFields != null;

  factory MediaProviderDto.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('download_config_fields')) {
      throw const FormatException(
        'provider.download_config_fields must be an array or null',
      );
    }
    final rawDownloadFields = json['download_config_fields'];
    return MediaProviderDto(
      providerKey: _requiredString(json, 'provider_key', path: 'provider'),
      displayName: _requiredString(json, 'display_name', path: 'provider'),
      libraryConfigFields: _requiredFieldList(
        json['library_config_fields'],
        path: 'provider.library_config_fields',
      ),
      downloadConfigFields: rawDownloadFields == null
          ? null
          : _requiredFieldList(
              rawDownloadFields,
              path: 'provider.download_config_fields',
            ),
    );
  }
}

String _requiredString(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$path.$key must be a non-empty string');
  }
  return value;
}

String? _optionalString(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  if (!json.containsKey(key) || json[key] == null) {
    return null;
  }
  final value = json[key];
  if (value is! String) {
    throw FormatException('$path.$key must be a string or null');
  }
  return value;
}

bool _requiredBool(
  Map<String, dynamic> json,
  String key, {
  required String path,
}) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException('$path.$key must be a boolean');
  }
  return value;
}

List<ProviderConfigFieldDto> _requiredFieldList(
  Object? value, {
  required String path,
}) {
  if (value is! List) {
    throw FormatException('$path must be an array');
  }
  final result = <ProviderConfigFieldDto>[];
  final keys = <String>{};
  for (var index = 0; index < value.length; index++) {
    final item = value[index];
    if (item is! Map) {
      throw FormatException('$path[$index] must be an object');
    }
    final field = ProviderConfigFieldDto.fromJson(
      Map<String, dynamic>.from(item),
      path: '$path[$index]',
    );
    if (!keys.add(field.key)) {
      throw FormatException('$path contains duplicate field "${field.key}"');
    }
    result.add(field);
  }
  return List<ProviderConfigFieldDto>.unmodifiable(result);
}
