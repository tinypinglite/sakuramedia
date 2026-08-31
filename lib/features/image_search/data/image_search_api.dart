import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/image_search/data/image_search_session_dto.dart';
import 'package:sakuramedia/features/image_search/data/image_search_target.dart';

class ImageSearchApi {
  const ImageSearchApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<ImageSearchSessionDto> createSession({
    required Uint8List fileBytes,
    required String fileName,
    String? mimeType,
    int pageSize = 20,
    List<int>? movieIds,
    List<int>? excludeMovieIds,
    double? scoreThreshold,
    ImageSearchTarget target = ImageSearchTarget.thumbnail,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
        contentType: _mediaTypeFromMimeType(mimeType),
      ),
      'page_size': '$pageSize',
      if (_encodeIdList(movieIds).isNotEmpty)
        'movie_ids': _encodeIdList(movieIds),
      if (_encodeIdList(excludeMovieIds).isNotEmpty)
        'exclude_movie_ids': _encodeIdList(excludeMovieIds),
      if (scoreThreshold != null) 'score_threshold': '$scoreThreshold',
    });
    final response = await _apiClient.post(
      _sessionPath(target),
      data: formData,
    );
    return ImageSearchSessionDto.fromJson(response, target: target);
  }

  Future<ImageSearchSessionDto> createTextSession({
    required String text,
    int pageSize = 20,
    List<int>? movieIds,
    List<int>? excludeMovieIds,
    double? scoreThreshold,
    ImageSearchTarget target = ImageSearchTarget.thumbnail,
  }) async {
    final formData = FormData.fromMap(<String, dynamic>{
      'text': text,
      'page_size': '$pageSize',
      if (_encodeIdList(movieIds).isNotEmpty)
        'movie_ids': _encodeIdList(movieIds),
      if (_encodeIdList(excludeMovieIds).isNotEmpty)
        'exclude_movie_ids': _encodeIdList(excludeMovieIds),
      if (scoreThreshold != null) 'score_threshold': '$scoreThreshold',
    });
    final response = await _apiClient.post(
      _textSessionPath(target),
      data: formData,
    );
    return ImageSearchSessionDto.fromJson(response, target: target);
  }

  Future<ImageSearchSessionDto> getNextResults({
    required String sessionId,
    required String cursor,
    ImageSearchTarget target = ImageSearchTarget.thumbnail,
  }) async {
    final response = await _apiClient.get(
      '${_sessionPath(target)}/$sessionId/results',
      queryParameters: <String, dynamic>{'cursor': cursor},
    );
    return ImageSearchSessionDto.fromJson(response, target: target);
  }

  String _sessionPath(ImageSearchTarget target) {
    return switch (target) {
      ImageSearchTarget.thumbnail => '/image-search/sessions',
      ImageSearchTarget.plot => '/image-search/plot-sessions',
    };
  }

  String _textSessionPath(ImageSearchTarget target) {
    return switch (target) {
      ImageSearchTarget.thumbnail => '/image-search/text-sessions',
      ImageSearchTarget.plot => '/image-search/plot-text-sessions',
    };
  }

  String _encodeIdList(List<int>? ids) {
    if (ids == null || ids.isEmpty) {
      return '';
    }
    final seen = <int>{};
    final values = <int>[];
    for (final id in ids) {
      if (id <= 0 || seen.contains(id)) {
        continue;
      }
      seen.add(id);
      values.add(id);
    }
    return values.join(',');
  }

  MediaType? _mediaTypeFromMimeType(String? mimeType) {
    final normalized = mimeType?.trim();
    if (normalized == null || normalized.isEmpty || !normalized.contains('/')) {
      return null;
    }
    final parts = normalized.split('/');
    if (parts.length != 2) {
      return null;
    }
    return MediaType(parts[0], parts[1]);
  }
}
