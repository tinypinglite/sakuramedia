import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/recent_views/data/dto/recent_view_dto.dart';

class RecentViewsApi {
  const RecentViewsApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  /// 后端保留上限；一次拉全量，区块取前几条、更多页列全。
  static const int _listLimit = 200;

  Future<void> record({
    required RecentViewEntityType entityType,
    required int entityId,
  }) {
    return _apiClient.postNoContent(
      '/view-history',
      data: <String, dynamic>{
        'entity_type': entityType.apiValue,
        'entity_id': entityId,
      },
    );
  }

  Future<List<RecentViewEntryDto>> list() async {
    final response = await _apiClient.get(
      '/view-history',
      queryParameters: <String, dynamic>{'limit': _listLimit},
    );
    final items = response['items'];
    if (items is! List) {
      return const <RecentViewEntryDto>[];
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(RecentViewEntryDto.tryFromJson)
        .whereType<RecentViewEntryDto>()
        .toList(growable: false);
  }
}
