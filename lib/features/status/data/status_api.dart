import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';

class StatusApi {
  const StatusApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<StatusDto> getStatus() async {
    final response = await _apiClient.get('/status');
    return StatusDto.fromJson(response);
  }
}
