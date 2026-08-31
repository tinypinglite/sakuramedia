import 'package:sakuramedia/core/json/json_parse.dart';

enum MediaLibraryBackend { local, cloud115 }

extension MediaLibraryBackendX on MediaLibraryBackend {
  String get wireValue => switch (this) {
    MediaLibraryBackend.local => 'local',
    MediaLibraryBackend.cloud115 => 'cloud115',
  };

  static MediaLibraryBackend fromWire(dynamic value) => switch (value) {
    'cloud115' => MediaLibraryBackend.cloud115,
    _ => MediaLibraryBackend.local,
  };
}

enum Cloud115LoginApp {
  web,
  android,
  ios,
  linux,
  mac,
  windows,
  tv,
  alipaymini,
  wechatmini,
  qandroid,
}

extension Cloud115LoginAppX on Cloud115LoginApp {
  String get wireValue => name;

  String get label => switch (this) {
    Cloud115LoginApp.web => '网页版',
    Cloud115LoginApp.android => 'Android',
    Cloud115LoginApp.ios => 'iOS',
    Cloud115LoginApp.linux => 'Linux',
    Cloud115LoginApp.mac => 'macOS',
    Cloud115LoginApp.windows => 'Windows',
    Cloud115LoginApp.tv => 'TV',
    Cloud115LoginApp.alipaymini => '支付宝小程序',
    Cloud115LoginApp.wechatmini => '微信小程序',
    Cloud115LoginApp.qandroid => 'Android（qandroid 登录槽）',
  };

  bool get isRecommended => this == Cloud115LoginApp.alipaymini;

  static Cloud115LoginApp fromWire(dynamic value) {
    return Cloud115LoginApp.values.firstWhere(
      (item) => item.wireValue == value,
      orElse: () => Cloud115LoginApp.alipaymini,
    );
  }
}

class MediaLibraryDto {
  const MediaLibraryDto({
    required this.id,
    required this.name,
    this.backend = MediaLibraryBackend.local,
    this.backendConfig = const <String, dynamic>{},
    String? rootPath,
    required this.createdAt,
    required this.updatedAt,
  }) : _legacyRootPath = rootPath;

  final int id;
  final String name;
  final MediaLibraryBackend backend;
  final Map<String, dynamic> backendConfig;
  final String? _legacyRootPath;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLocal => backend == MediaLibraryBackend.local;
  bool get isCloud115 => backend == MediaLibraryBackend.cloud115;

  /// 下拉选项 / 徽章 / 目标库选择器等展示场景的通用标签：115 库自带后缀。
  String get displayLabel => isCloud115 ? '$name（115）' : name;

  String get rootPath =>
      backendConfig['root_path'] as String? ?? _legacyRootPath ?? '';

  String get rootCid => backendConfig['root_cid'] as String? ?? '';

  Cloud115LoginApp get cloud115App =>
      Cloud115LoginAppX.fromWire(backendConfig['app']);

  factory MediaLibraryDto.fromJson(Map<String, dynamic> json) {
    final rawConfig = json['backend_config'];
    final config =
        rawConfig is Map
            ? rawConfig.map(
              (dynamic key, dynamic value) => MapEntry(key.toString(), value),
            )
            : <String, dynamic>{
              if (json['root_path'] is String) 'root_path': json['root_path'],
            };
    return MediaLibraryDto(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      backend: MediaLibraryBackendX.fromWire(json['backend']),
      backendConfig: config,
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }
}

class CreateMediaLibraryPayload {
  const CreateMediaLibraryPayload({required this.name, required this.rootPath});

  final String name;
  final String rootPath;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'backend': MediaLibraryBackend.local.wireValue,
      'backend_config': <String, dynamic>{'root_path': rootPath},
    };
  }
}

class UpdateMediaLibraryPayload {
  const UpdateMediaLibraryPayload({this.name});

  final String? name;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{if (name != null) 'name': name};
  }
}
