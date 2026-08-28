import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';

/// 一次播放器路由实例的稳定身份与启动参数。
@immutable
class MoviePlayerScope {
  const MoviePlayerScope({
    required this.movieNumber,
    required this.baseUrl,
    this.playbackDelivery,
    this.initialMediaId,
    this.initialPositionSeconds,
    this.progressReportInterval = const Duration(seconds: 5),
  });

  final String movieNumber;
  final String baseUrl;
  final MoviePlaybackDelivery? playbackDelivery;
  final int? initialMediaId;
  final int? initialPositionSeconds;
  final Duration progressReportInterval;

  @override
  bool operator ==(Object other) =>
      other is MoviePlayerScope &&
      other.movieNumber == movieNumber &&
      other.baseUrl == baseUrl &&
      other.playbackDelivery == playbackDelivery &&
      other.initialMediaId == initialMediaId &&
      other.initialPositionSeconds == initialPositionSeconds &&
      other.progressReportInterval == progressReportInterval;

  @override
  int get hashCode => Object.hash(
    movieNumber,
    baseUrl,
    playbackDelivery,
    initialMediaId,
    initialPositionSeconds,
    progressReportInterval,
  );
}
