import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_dto.dart';

/// `/system/plugins` 管理接口与插件私有配置读写。
class PluginsApi {
  const PluginsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<PluginSummaryDto>> list() async {
    final response = await _apiClient.getList('/system/plugins');
    return response.map(PluginSummaryDto.fromJson).toList(growable: false);
  }

  Future<void> install({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      'enable': 'true',
    });
    await _apiClient.post('/system/plugins', data: formData);
  }

  /// 直接查询插件声明的 GitHub Release API；不会携带 SakuraMedia 登录令牌。
  Future<PluginReleaseUpdate?> checkForUpdate(PluginSummaryDto plugin) async {
    final releaseApiUrl = plugin.releaseApiUrl;
    if (releaseApiUrl == null) {
      return null;
    }
    final release = await _apiClient.get(releaseApiUrl, requiresAuth: false);
    final latestVersion = _PluginVersion.parse(
      asStringOrNull(release['tag_name'], trim: true) ??
          (throw const FormatException('Release 缺少 tag_name')),
    );
    final installedVersion = _PluginVersion.parse(plugin.version);
    if (latestVersion.compareTo(installedVersion) <= 0) {
      return null;
    }

    final asset = _findZipAsset(release['assets']);
    if (asset == null) {
      throw const FormatException('Release 未包含 .zip 插件包');
    }
    final assetUrl = asStringOrNull(asset['browser_download_url'], trim: true);
    final assetFileName = asStringOrNull(asset['name'], trim: true);
    if (assetUrl == null || assetFileName == null) {
      throw const FormatException('Release 插件包信息不完整');
    }
    return PluginReleaseUpdate(
      version: latestVersion.toString(),
      notes: asStringOrNull(release['body']) ?? '',
      assetUrl: assetUrl,
      assetFileName: assetFileName,
      sha256: _sha256FromDigest(asStringOrNull(asset['digest'], trim: true)),
    );
  }

  Future<Uint8List> downloadUpdate(PluginReleaseUpdate update) {
    return _apiClient.getBytes(update.assetUrl, requiresAuth: false);
  }

  Future<String> upgrade({
    required String pluginId,
    required PluginReleaseUpdate update,
    required Uint8List fileBytes,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: update.assetFileName,
      ),
      if (update.sha256 != null) 'sha256': update.sha256,
    });
    final response = await _apiClient.post(
      '/system/plugins/$pluginId/upgrade',
      data: formData,
    );
    return asStringOrNull(response['version'], trim: true) ??
        (throw const FormatException('升级响应缺少 version'));
  }

  Future<PluginSummaryDto> setEnabled(
    String pluginId, {
    required bool enabled,
  }) async {
    final response = await _apiClient.patch(
      '/system/plugins/$pluginId',
      queryParameters: <String, dynamic>{'enabled': enabled},
    );
    return PluginSummaryDto.fromJson(response);
  }

  Future<void> remove(String pluginId) async {
    await _apiClient.delete('/system/plugins/$pluginId');
  }

  Future<PluginSettingsDto> getSettings(String pluginId) async {
    final response = await _apiClient.get('/system/plugins/$pluginId/settings');
    return PluginSettingsDto.fromJson(response);
  }

  Future<PluginSettingsDto> updateSettings(
    String pluginId, {
    required Map<String, dynamic> settings,
  }) async {
    final response = await _apiClient.put(
      '/system/plugins/$pluginId/settings',
      data: settings,
    );
    return PluginSettingsDto.fromJson(response);
  }
}

Map<String, dynamic>? _findZipAsset(dynamic value) {
  if (value is! List) {
    return null;
  }
  for (final item in value) {
    final asset = asMapOrNull(item);
    final name = asStringOrNull(asset?['name'], trim: true);
    if (name != null && name.toLowerCase().endsWith('.zip')) {
      return asset;
    }
  }
  return null;
}

String? _sha256FromDigest(String? digest) {
  if (digest == null) {
    return null;
  }
  final match = RegExp(r'^sha256:([a-fA-F0-9]{64})$').firstMatch(digest);
  return match?.group(1)?.toLowerCase();
}

class _PluginVersion implements Comparable<_PluginVersion> {
  const _PluginVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  factory _PluginVersion.parse(String value) {
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(value.trim());
    if (match == null) {
      throw FormatException('不支持的插件版本格式: $value');
    }
    return _PluginVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  @override
  int compareTo(_PluginVersion other) {
    final majorComparison = major.compareTo(other.major);
    if (majorComparison != 0) {
      return majorComparison;
    }
    final minorComparison = minor.compareTo(other.minor);
    if (minorComparison != 0) {
      return minorComparison;
    }
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}
