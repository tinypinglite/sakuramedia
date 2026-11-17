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

class ProviderLoginCookieCaptureDto {
  const ProviderLoginCookieCaptureDto({
    required this.url,
    required this.captureNames,
    required this.requiredNames,
  });

  final String url;
  final List<String> captureNames;
  final List<String> requiredNames;

  factory ProviderLoginCookieCaptureDto.fromJson(
    Map<String, dynamic> json, {
    required String path,
  }) {
    return ProviderLoginCookieCaptureDto(
      url: _requiredString(json, 'url', path: path),
      captureNames: _requiredStringList(
        json['capture_names'],
        path: '$path.capture_names',
      ),
      requiredNames: _requiredStringList(
        json['required_names'],
        path: '$path.required_names',
        allowEmpty: true,
      ),
    );
  }
}

class ProviderLoginLocalStorageCaptureDto {
  const ProviderLoginLocalStorageCaptureDto({
    required this.origin,
    required this.requiredJsonKeys,
  });

  final String origin;
  final List<String> requiredJsonKeys;

  factory ProviderLoginLocalStorageCaptureDto.fromJson(
    Map<String, dynamic> json, {
    required String path,
  }) {
    return ProviderLoginLocalStorageCaptureDto(
      origin: _requiredString(json, 'origin', path: path),
      requiredJsonKeys: _requiredStringList(
        json['required_json_keys'],
        path: '$path.required_json_keys',
        allowEmpty: true,
      ),
    );
  }
}

class ProviderLoginDto {
  const ProviderLoginDto({
    required this.mode,
    required this.startUrl,
    required this.allowedHosts,
    required this.cookieCaptures,
    required this.localStorageCaptures,
    required this.managedConfigKeys,
    required this.timeoutSeconds,
  });

  final String mode;
  final String startUrl;
  final List<String> allowedHosts;
  final List<ProviderLoginCookieCaptureDto> cookieCaptures;
  final List<ProviderLoginLocalStorageCaptureDto> localStorageCaptures;
  final List<String> managedConfigKeys;
  final int timeoutSeconds;

  factory ProviderLoginDto.fromJson(
    Map<String, dynamic> json, {
    required String path,
  }) {
    final rawTimeout = json['timeout_seconds'];
    if (rawTimeout is! int || rawTimeout <= 0) {
      throw FormatException('$path.timeout_seconds must be a positive integer');
    }
    return ProviderLoginDto(
      mode: _requiredString(json, 'mode', path: path),
      startUrl: _requiredString(json, 'start_url', path: path),
      allowedHosts: _requiredStringList(
        json['allowed_hosts'],
        path: '$path.allowed_hosts',
      ),
      cookieCaptures: _requiredObjectList(
        json['cookie_captures'],
        path: '$path.cookie_captures',
        parse: (item, itemPath) =>
            ProviderLoginCookieCaptureDto.fromJson(item, path: itemPath),
      ),
      localStorageCaptures: _requiredObjectList(
        json['local_storage_captures'],
        path: '$path.local_storage_captures',
        parse: (item, itemPath) =>
            ProviderLoginLocalStorageCaptureDto.fromJson(item, path: itemPath),
      ),
      managedConfigKeys: _requiredStringList(
        json['managed_config_keys'],
        path: '$path.managed_config_keys',
        allowEmpty: true,
      ),
      timeoutSeconds: rawTimeout,
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
    this.libraryLogin,
  });

  final String providerKey;
  final String displayName;
  final List<ProviderConfigFieldDto> libraryConfigFields;

  /// `null` 表示该 Provider 不支持下载，空列表表示支持下载但无需配置。
  final List<ProviderConfigFieldDto>? downloadConfigFields;
  final ProviderLoginDto? libraryLogin;

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
      libraryLogin: switch (json['library_login']) {
        null => null,
        final Map<dynamic, dynamic> value => ProviderLoginDto.fromJson(
          Map<String, dynamic>.from(value),
          path: 'provider.library_login',
        ),
        _ => throw const FormatException(
          'provider.library_login must be an object or null',
        ),
      },
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

List<String> _requiredStringList(
  Object? value, {
  required String path,
  bool allowEmpty = false,
}) {
  if (value is! List) {
    throw FormatException('$path must be an array');
  }
  if (!allowEmpty && value.isEmpty) {
    throw FormatException('$path must not be empty');
  }
  final result = <String>[];
  for (var index = 0; index < value.length; index++) {
    final item = value[index];
    if (item is! String || item.trim().isEmpty) {
      throw FormatException('$path[$index] must be a non-empty string');
    }
    if (result.contains(item)) {
      throw FormatException('$path contains duplicate item "$item"');
    }
    result.add(item);
  }
  return List<String>.unmodifiable(result);
}

List<T> _requiredObjectList<T>(
  Object? value, {
  required String path,
  required T Function(Map<String, dynamic> json, String path) parse,
}) {
  if (value is! List) {
    throw FormatException('$path must be an array');
  }
  final result = <T>[];
  for (var index = 0; index < value.length; index++) {
    final item = value[index];
    if (item is! Map) {
      throw FormatException('$path[$index] must be an object');
    }
    result.add(parse(Map<String, dynamic>.from(item), '$path[$index]'));
  }
  return List<T>.unmodifiable(result);
}
