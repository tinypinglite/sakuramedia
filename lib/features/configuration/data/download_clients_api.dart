import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/configuration/data/download_client_dto.dart';

class DownloadClientsApi {
  const DownloadClientsApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<DownloadClientDto>> getClients() async {
    final response = await _apiClient.getList('/download-clients');
    return response.map(DownloadClientDto.fromJson).toList(growable: false);
  }

  Future<DownloadClientDto> createClient(
    CreateDownloadClientPayload payload,
  ) async {
    final response = await _apiClient.post(
      '/download-clients',
      data: payload.toJson(),
    );
    return DownloadClientDto.fromJson(response);
  }

  Future<DownloadClientDto> updateClient({
    required int clientId,
    required UpdateDownloadClientPayload payload,
  }) async {
    final response = await _apiClient.patch(
      '/download-clients/$clientId',
      data: payload.toJson(),
    );
    return DownloadClientDto.fromJson(response);
  }

  Future<void> deleteClient(int clientId) {
    return _apiClient.deleteNoContent('/download-clients/$clientId');
  }
}
