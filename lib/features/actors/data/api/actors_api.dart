import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_candidate_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_filter_options_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_movie_year_dto.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/tags/data/tag_list_item_dto.dart';

class ActorsApi {
  const ActorsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PaginatedResponseDto<ActorListItemDto>> getActors({
    ActorSubscriptionStatus subscriptionStatus = ActorSubscriptionStatus.all,
    ActorGender gender = ActorGender.all,
    int? ageMin,
    int? ageMax,
    int? heightMin,
    int? heightMax,
    List<String> cups = const <String>[],
    bool hasPlayableMovies = false,
    String? sort,
    String? query,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParameters = <String, dynamic>{
      'subscription_status': subscriptionStatus.apiValue,
      'gender': gender.apiValue,
      'page': page,
      'page_size': pageSize,
    };
    if (query != null && query.isNotEmpty) {
      queryParameters['query'] = query;
    }
    if (hasPlayableMovies) {
      queryParameters['has_playable_movies'] = true;
    }
    if (sort != null && sort.isNotEmpty) {
      queryParameters['sort'] = sort;
    }
    if (ageMin != null) {
      queryParameters['age_min'] = ageMin;
    }
    if (ageMax != null) {
      queryParameters['age_max'] = ageMax;
    }
    if (heightMin != null) {
      queryParameters['height_min'] = heightMin;
    }
    if (heightMax != null) {
      queryParameters['height_max'] = heightMax;
    }
    if (cups.isNotEmpty) {
      queryParameters['cups'] = cups.join(',');
    }

    final response = await _apiClient.get(
      '/actors',
      queryParameters: queryParameters,
    );
    return PaginatedResponseDto<ActorListItemDto>.fromJson(
      response,
      ActorListItemDto.fromJson,
    );
  }

  Future<ActorFilterOptionsDto> getActorFilterOptions({
    ActorSubscriptionStatus subscriptionStatus = ActorSubscriptionStatus.all,
    ActorGender gender = ActorGender.all,
  }) async {
    final response = await _apiClient.get(
      '/actors/filter-options',
      queryParameters: <String, dynamic>{
        'subscription_status': subscriptionStatus.apiValue,
        'gender': gender.apiValue,
      },
    );
    return ActorFilterOptionsDto.fromJson(response);
  }

  Future<ActorDetailDto> getActorDetail({required int actorId}) async {
    final response = await _apiClient.get('/actors/$actorId');
    return ActorDetailDto.fromJson(response);
  }

  Future<ActorDetailDto> updateActor({
    required int actorId,
    required int expectedRevision,
    required Map<String, dynamic> changes,
  }) async {
    final response = await _apiClient.patch(
      '/actors/$actorId',
      data: <String, dynamic>{
        'expected_revision': expectedRevision,
        ...changes,
      },
    );
    return ActorDetailDto.fromJson(response);
  }

  /// 创建本地演员。
  Future<ActorDetailDto> createLocalActor({
    required String name,
    String? aliasName,
    int gender = 1,
  }) async {
    final normalizedAlias = aliasName?.trim() ?? '';
    final response = await _apiClient.post(
      '/actors',
      data: <String, dynamic>{
        'name': name.trim(),
        if (normalizedAlias.isNotEmpty) 'alias_name': normalizedAlias,
        'gender': gender,
      },
    );
    return ActorDetailDto.fromJson(response);
  }

  Future<ActorDetailDto> uploadActorProfileImage({
    required int actorId,
    required int expectedRevision,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final response = await _apiClient.put(
      '/actors/$actorId/profile-image',
      queryParameters: <String, dynamic>{'expected_revision': expectedRevision},
      data: formData,
    );
    return ActorDetailDto.fromJson(response);
  }

  Future<ActorDetailDto> clearActorProfileImage({
    required int actorId,
    required int expectedRevision,
  }) async {
    final response = await _apiClient.delete(
      '/actors/$actorId/profile-image',
      queryParameters: <String, dynamic>{'expected_revision': expectedRevision},
    );
    return ActorDetailDto.fromJson(response);
  }

  Future<List<int>> getActorMovieIds({required int actorId}) async {
    final response = await _apiClient.getValueList(
      '/actors/$actorId/movie-ids',
    );
    return response
        .map(
          (dynamic value) => value is int ? value : int.tryParse('$value') ?? 0,
        )
        .where((int id) => id > 0)
        .toList(growable: false);
  }

  Future<List<ActorMovieYearDto>> getActorMovieYears({
    required int actorId,
  }) async {
    final response = await _apiClient.getList('/actors/$actorId/years');
    return response
        .map(ActorMovieYearDto.fromJson)
        .where((item) => item.year > 0)
        .toList(growable: false);
  }

  Future<List<TagListItemDto>> getActorTags({required int actorId}) async {
    final response = await _apiClient.getList('/actors/$actorId/tags');
    return response.map(TagListItemDto.fromJson).toList(growable: false);
  }

  Future<List<ActorCandidateDto>> searchActorCandidates({
    required String query,
    int limit = 20,
  }) async {
    final response = await _apiClient.getList(
      '/actors/gfriends/search',
      queryParameters: <String, dynamic>{'query': query, 'limit': limit},
    );
    return response
        .map(ActorCandidateDto.fromJson)
        .where((item) => item.candidateId.isNotEmpty)
        .toList(growable: false);
  }

  Future<ActorDetailDto> importActorCandidate({
    required String candidateId,
  }) async {
    final response = await _apiClient.post(
      '/actors/gfriends/import',
      data: <String, dynamic>{'candidate_id': candidateId},
    );
    return ActorDetailDto.fromJson(response);
  }

  Future<void> subscribeActor({required int actorId}) {
    return _apiClient.putNoContent('/actors/$actorId/subscription');
  }

  Future<void> unsubscribeActor({required int actorId}) {
    return _apiClient.deleteNoContent('/actors/$actorId/subscription');
  }

  Future<ActorDetailDto> mergeActors({
    required int actorId,
    required List<int> sourceActorIds,
  }) async {
    final response = await _apiClient.post(
      '/actors/$actorId/merge',
      data: <String, dynamic>{'source_actor_ids': sourceActorIds},
    );
    return ActorDetailDto.fromJson(response);
  }
}
