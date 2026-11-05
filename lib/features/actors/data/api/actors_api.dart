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
import 'package:sakuramedia/features/tags/data/tag_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/l10n/app_localizations_zh.dart';

class ActorsApi {
  const ActorsApi({
    required ApiClient apiClient,
    AppLocalizations Function()? l10n,
  }) : _apiClient = apiClient,
       _l10n = l10n;

  final ApiClient _apiClient;
  final AppLocalizations Function()? _l10n;

  AppLocalizations get _localizations => _l10n?.call() ?? AppLocalizationsZh();

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

  /// 创建没有 JavDB 身份的用户自建女优。
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

  Stream<ActorSearchStreamUpdate> searchOnlineActorsStream({
    required String actorName,
  }) {
    return _apiClient
        .postSse(
          '/actors/metadata-imports',
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

  ActorSearchStreamUpdate _mapActorSearchStreamEvent(ApiSseEvent event) {
    final payload = event.jsonData;

    switch (event.event) {
      case 'search_started':
        return ActorSearchStreamUpdate(
          stage: 'search_started',
          message: _localizations.sseActorSearchingExternal,
        );
      case 'actor_found':
        return ActorSearchStreamUpdate(
          stage: 'actor_found',
          message: _localizations.sseActorCandidatesFetched,
          total: payload['total'] as int?,
        );
      case 'upsert_started':
        return ActorSearchStreamUpdate(
          stage: 'upsert_started',
          message: _localizations.sseActorImportingOnline,
          total: payload['total'] as int?,
        );
      case 'image_download_started':
        return ActorSearchStreamUpdate(
          stage: 'image_download_started',
          message: _localizations.sseActorDownloadingAvatar(
            payload['index'] as int? ?? 0,
            payload['total'] as int? ?? 0,
          ),
          current: payload['index'] as int?,
          total: payload['total'] as int?,
        );
      case 'image_download_finished':
        return ActorSearchStreamUpdate(
          stage: 'image_download_finished',
          message: _localizations.sseActorDownloadingAvatar(
            payload['index'] as int? ?? 0,
            payload['total'] as int? ?? 0,
          ),
          current: payload['index'] as int?,
          total: payload['total'] as int?,
        );
      case 'upsert_finished':
        return ActorSearchStreamUpdate(
          stage: 'upsert_finished',
          message: _localizations.sseActorOnlineImportFinished,
          stats: CatalogSearchStreamStats.fromLooseJson(payload),
        );
      case 'completed':
        return ActorSearchStreamUpdate(
          stage: 'completed',
          message: _localizations.sseActorOnlineSearchFinished,
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
          message: _localizations.sseActorSyncingOnlineResults,
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
