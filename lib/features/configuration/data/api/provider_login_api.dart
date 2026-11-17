import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_login_dto.dart';

class ProviderLoginApi {
  const ProviderLoginApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ProviderLoginSessionDto> createSession({
    required String providerKey,
    required List<ProviderLoginCookieSetPayload> cookies,
    required List<ProviderLoginLocalStorageSetPayload> localStorage,
  }) async {
    final response = await _apiClient.post(
      '/media-libraries/provider-login-sessions',
      data: <String, dynamic>{
        'provider_key': providerKey,
        'cookies': cookies.map((item) => item.toJson()).toList(growable: false),
        'local_storage': localStorage
            .map((item) => item.toJson())
            .toList(growable: false),
      },
    );
    return ProviderLoginSessionDto.fromJson(response);
  }

  Future<void> deleteSession(String sessionId) {
    return _apiClient.deleteNoContent(
      '/media-libraries/provider-login-sessions/$sessionId',
    );
  }
}
