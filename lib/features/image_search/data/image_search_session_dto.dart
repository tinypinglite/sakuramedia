import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';

class ImageSearchSessionDto {
  const ImageSearchSessionDto({
    required this.sessionId,
    required this.status,
    required this.pageSize,
    required this.nextCursor,
    required this.expiresAt,
    required this.items,
  });

  final String sessionId;
  final String status;
  final int pageSize;
  final String? nextCursor;
  final DateTime? expiresAt;
  final List<ImageSearchResultItemDto> items;

  factory ImageSearchSessionDto.fromJson(Map<String, dynamic> json) {
    final itemsValue = json['items'];
    return ImageSearchSessionDto(
      sessionId: json['session_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      pageSize: json['page_size'] as int? ?? 0,
      nextCursor: json['next_cursor'] as String?,
      expiresAt: _dateTimeFromJson(json['expires_at']),
      items:
          itemsValue is List
              ? itemsValue
                  .whereType<Object?>()
                  .map(
                    (Object? item) =>
                        ImageSearchResultItemDto.fromJson(_toMap(item)),
                  )
                  .toList(growable: false)
              : const <ImageSearchResultItemDto>[],
    );
  }

  static DateTime? _dateTimeFromJson(dynamic value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  static Map<String, dynamic> _toMap(Object? value) {
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
