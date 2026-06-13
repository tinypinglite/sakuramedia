import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/videos/data/person_dto.dart';

/// 非 JAV 视频域的人物接口（`/persons`）。
class PersonsApi {
  const PersonsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PaginatedResponseDto<PersonDto>> getPersons({
    String? query,
    String? sort,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParameters = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    final trimmedQuery = query?.trim();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      queryParameters['query'] = trimmedQuery;
    }
    if (sort != null && sort.isNotEmpty) {
      queryParameters['sort'] = sort;
    }

    final response = await _apiClient.get(
      '/persons',
      queryParameters: queryParameters,
    );
    return PaginatedResponseDto<PersonDto>.fromJson(
      response,
      PersonDto.fromJson,
    );
  }

  Future<PersonDto> createPerson({
    required String name,
    int gender = 0,
  }) async {
    final response = await _apiClient.post(
      '/persons',
      data: <String, dynamic>{'name': name.trim(), 'gender': gender},
    );
    return PersonDto.fromJson(response);
  }

  Future<PersonDto> getPerson({required int personId}) async {
    final response = await _apiClient.get('/persons/$personId');
    return PersonDto.fromJson(response);
  }

  Future<PersonDto> updatePerson({
    required int personId,
    required PersonUpdatePayload payload,
  }) async {
    final response = await _apiClient.patch(
      '/persons/$personId',
      data: payload.toJson(),
    );
    return PersonDto.fromJson(response);
  }

  Future<void> deletePerson(int personId) {
    return _apiClient.deleteNoContent('/persons/$personId');
  }
}
