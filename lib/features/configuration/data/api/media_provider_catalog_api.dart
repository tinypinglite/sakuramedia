import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';

/// Provider 目录 API。
class MediaProviderCatalogApi {
  const MediaProviderCatalogApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<MediaProviderDto>> getProviders() async {
    final response = await _apiClient.getList('/media-libraries/providers');
    return response.map(MediaProviderDto.fromJson).toList(growable: false);
  }
}
