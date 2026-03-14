import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_sse_event.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/data/actor_search_stream_update.dart';
import 'package:sakuramedia/features/actors/presentation/actor_filter_state.dart';
import 'package:sakuramedia/features/search/data/catalog_search_stream_stats.dart';

class ActorsApi {
  const ActorsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<PaginatedResponseDto<ActorListItemDto>> getActors({
    ActorSubscriptionStatus subscriptionStatus = ActorSubscriptionStatus.all,
    ActorGender gender = ActorGender.all,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/actors',
      queryParameters: <String, dynamic>{
        'subscription_status': subscriptionStatus.apiValue,
        'gender': gender.apiValue,
        'page': page,
        'page_size': pageSize,
      },
    );
    return PaginatedResponseDto<ActorListItemDto>.fromJson(
      response,
      ActorListItemDto.fromJson,
    );
  }

  Future<ActorListItemDto> getActorDetail({required int actorId}) async {
    final response = await _apiClient.get('/actors/$actorId');
    return ActorListItemDto.fromJson(response);
  }

  Future<List<ActorListItemDto>> searchLocalActors({
    required String query,
  }) async {
    final response = await _apiClient.getList(
      '/actors/search/local',
      queryParameters: <String, dynamic>{'query': query.trim()},
    );
    return response.map(ActorListItemDto.fromJson).toList(growable: false);
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
          stats:
              payload.containsKey('stats') || payload.containsKey('total')
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
