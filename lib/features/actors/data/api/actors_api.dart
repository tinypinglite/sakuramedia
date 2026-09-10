import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_sse_event.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_filter_options_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_movie_year_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_search_stream_update.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/search/data/catalog_search_stream_stats.dart';

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
    String? sort,
    int page = 1,
    int pageSize = 20,
  }) async {
    final queryParameters = <String, dynamic>{
      'subscription_status': subscriptionStatus.apiValue,
      'gender': gender.apiValue,
      'page': page,
      'page_size': pageSize,
    };
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

  Stream<ActorSearchStreamUpdate> searchOnlineActorsStream({
    required String actorName,
  }) {
    return _apiClient
        .postSse(
          '/actors/search/javdb/stream',
          data: <String, dynamic>{'actor_name': actorName},
        )
        .map(_mapActorSearchStreamEvent);
  }

  Future<void> subscribeActor({required int actorId}) {
    return _apiClient.putNoContent('/actors/$actorId/subscription');
  }

  Future<void> unsubscribeActor({required int actorId}) {
    return _apiClient.deleteNoContent('/actors/$actorId/subscription');
  }

  ActorSearchStreamUpdate _mapActorSearchStreamEvent(ApiSseEvent event) {
    final payload = event.jsonData;

    switch (event.event) {
      case 'search_started':
        return const ActorSearchStreamUpdate(
          stage: 'search_started',
          message: '正在从外部数据源搜索女优',
        );
      case 'actor_found':
        return ActorSearchStreamUpdate(
          stage: 'actor_found',
          message: '已从在线源获取候选女优',
          total: payload['total'] as int?,
        );
      case 'upsert_started':
        return ActorSearchStreamUpdate(
          stage: 'upsert_started',
          message: '正在入库在线女优',
          total: payload['total'] as int?,
        );
      case 'image_download_started':
        return ActorSearchStreamUpdate(
          stage: 'image_download_started',
          message:
              '正在下载头像 ${payload['index'] as int? ?? 0}/${payload['total'] as int? ?? 0}',
          current: payload['index'] as int?,
          total: payload['total'] as int?,
        );
      case 'image_download_finished':
        return ActorSearchStreamUpdate(
          stage: 'image_download_finished',
          message:
              '正在下载头像 ${payload['index'] as int? ?? 0}/${payload['total'] as int? ?? 0}',
          current: payload['index'] as int?,
          total: payload['total'] as int?,
        );
      case 'upsert_finished':
        return ActorSearchStreamUpdate(
          stage: 'upsert_finished',
          message: '在线女优入库完成',
          stats: CatalogSearchStreamStats.fromLooseJson(payload),
        );
      case 'completed':
        return ActorSearchStreamUpdate(
          stage: 'completed',
          message: '在线搜索已完成',
          results: _parseActorResults(payload['actors']),
          success: payload['success'] as bool? ?? false,
          reason: payload['reason'] as String?,
          stats: payload.containsKey('stats') || payload.containsKey('total')
              ? CatalogSearchStreamStats.fromLooseJson(payload)
              : null,
        );
      default:
        return ActorSearchStreamUpdate(
          stage: event.event,
          message: '正在同步在线女优搜索结果',
        );
    }
  }

  List<ActorListItemDto> _parseActorResults(dynamic value) {
    if (value is! List) {
      return const <ActorListItemDto>[];
    }
    return value
        .whereType<Object?>()
        .map((item) => ActorListItemDto.fromJson(_toMap(item)))
        .toList(growable: false);
  }

  Map<String, dynamic> _toMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic data) => MapEntry(key.toString(), data),
      );
    }
    return const <String, dynamic>{};
  }
}
