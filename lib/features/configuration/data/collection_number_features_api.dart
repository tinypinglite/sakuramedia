import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/configuration/data/collection_number_features_dto.dart';

class CollectionNumberFeaturesApi {
  const CollectionNumberFeaturesApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<CollectionNumberFeaturesDto> getFeatures() async {
    final response = await _apiClient.get('/collection-number-features');
    return CollectionNumberFeaturesDto.fromJson(response);
  }

  Future<CollectionNumberFeaturesDto> updateFeatures(
    UpdateCollectionNumberFeaturesPayload payload, {
    required bool applyNow,
  }) async {
    final response = await _apiClient.patch(
      '/collection-number-features',
      data: payload.toJson(),
      queryParameters: <String, dynamic>{'apply_now': applyNow},
    );
    return CollectionNumberFeaturesDto.fromJson(response);
  }
}
