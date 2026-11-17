import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/configuration/data/dto/config_dto.dart';

class ConfigApi {
  const ConfigApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ConfigResourceDto> get() async {
    final response = await _apiClient.get('/config');
    return ConfigResourceDto.fromJson(response);
  }

  Future<ConfigUpdateResultDto> patch(Map<String, dynamic> partial) async {
    final response = await _apiClient.patch('/config', data: partial);
    return ConfigUpdateResultDto.fromJson(response);
  }
}
