import 'package:sakuramedia/core/json/json_parse.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/announcements/data/announcement_dto.dart';

class AnnouncementsApi {
  const AnnouncementsApi({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<AnnouncementDto>> getAnnouncements() async {
    final response = await _apiClient.get('/status/announcements');
    final rawItems = response['items'];
    if (rawItems is! List) {
      return const <AnnouncementDto>[];
    }

    final items = <AnnouncementDto>[];
    for (final rawItem in rawItems) {
      final map = asMapOrNull(rawItem);
      if (map == null) {
        continue;
      }
      final announcement = AnnouncementDto.tryFromJson(map);
      if (announcement != null) {
        items.add(announcement);
      }
    }
    return List<AnnouncementDto>.unmodifiable(items);
  }
}
