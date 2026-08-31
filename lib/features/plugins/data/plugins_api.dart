import 'dart:typed_data';

import 'package:dio/dio.dart';
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
