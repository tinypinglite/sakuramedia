import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_dto.dart';

class MetadataProviderLicenseApi {
  const MetadataProviderLicenseApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<MetadataProviderLicenseStatusDto> getStatus() async {
    final response = await _apiClient.get('/metadata-provider-license/status');
    return MetadataProviderLicenseStatusDto.fromJson(response);
  }

  Future<MetadataProviderLicenseConnectivityTestDto> testConnectivity() async {
    final response = await _apiClient.get(
      '/metadata-provider-license/connectivity-test',
    );
    return MetadataProviderLicenseConnectivityTestDto.fromJson(response);
  }

  Future<MetadataProviderLicenseStatusDto> activate({
    required String activationCode,
  }) async {
    final response = await _apiClient.post(
      '/metadata-provider-license/activate',
      data: <String, dynamic>{'activation_code': activationCode},
    );
    return MetadataProviderLicenseStatusDto.fromJson(response);
  }

  Future<MetadataProviderLicenseStatusDto> syncAuthorization() async {
    final response = await _apiClient.post('/metadata-provider-license/renew');
    return MetadataProviderLicenseStatusDto.fromJson(response);
  }
}
