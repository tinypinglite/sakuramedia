import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/configuration/data/dto/metadata_source_dto.dart';

class MetadataSourcesApi {
  const MetadataSourcesApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<MetadataSourceDto>> list() async {
    final response = await _apiClient.getList('/system/metadata-sources');
    return response.map(MetadataSourceDto.fromJson).toList(growable: false);
  }

  Future<void> reorder(List<String> pluginIds) async {
    await _apiClient.put(
      '/system/metadata-sources/order',
      data: <String, dynamic>{'plugin_ids': pluginIds},
    );
  }
}
