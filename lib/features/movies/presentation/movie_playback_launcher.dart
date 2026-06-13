import 'package:flutter/widgets.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/data/external_player_store.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';

/// 统一的影片播放入口：根据用户是否设置了默认外部播放器，决定跳应用内播放页
/// 还是直接拉起外部播放器。所有播放入口都应经由此函数，保证行为一致。
///
/// [movie] 可传入已加载的详情以避免重复请求（详情页场景）；缺省时按需拉取。
Future<void> launchMoviePlayback(
  BuildContext context, {
  required String movieNumber,
  int? mediaId,
  int? positionSeconds,
  MovieDetailDto? movie,
}) async {
  final store = _readExternalPlayerStore(context);
  const channel = ExternalPlayerChannel();

  // 未设置外部播放器、当前平台不支持、或偏好未注入（如局部测试树），
  // 直接走应用内播放页。
  if (store == null || !store.hasExternalPlayer || !channel.isSupported) {
    _pushInAppPlayer(
      context,
      movieNumber: movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
    );
    return;
  }

  final packageName = store.packageName!;

  // 外部播放器需要完整直链与标题，按需补齐影片详情。
  var detail = movie;
  if (detail == null) {
    try {
      detail = await context.read<MoviesApi>().getMovieDetail(
        movieNumber: movieNumber,
      );
    } catch (_) {
      detail = null;
    }
    if (!context.mounted) {
      return;
    }
  }

  final media = _resolvePlayableMedia(detail, mediaId);
  final baseUrl = context.read<SessionStore>().baseUrl;
  final resolvedUrl =
      media == null
          ? null
          : resolveMediaUrl(rawUrl: media.playUrl, baseUrl: baseUrl);

  // 拿不到可播放直链时回落到应用内播放页。
  if (detail == null || media == null || resolvedUrl == null || resolvedUrl.isEmpty) {
    _pushInAppPlayer(
      context,
      movieNumber: movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
    );
    return;
  }

  final resumeSeconds =
      positionSeconds ?? media.progress?.lastPositionSeconds ?? 0;
  final title =
      detail.preferredTitle.isNotEmpty ? detail.preferredTitle : movieNumber;

  final launched = await channel.launch(
    packageName: packageName,
    url: resolvedUrl,
    title: title,
    positionMs: resumeSeconds > 0 ? resumeSeconds * 1000 : null,
  );
  if (!context.mounted) {
    return;
  }
  if (!launched) {
    // 外部播放器不可用（可能已卸载），提示并回落到应用内播放。
    showToast('外部播放器不可用，已使用应用内播放');
    _pushInAppPlayer(
      context,
      movieNumber: movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
    );
  }
}

/// 安全读取偏好；在未注入 Provider 的局部上下文中返回 null（降级为应用内播放）。
ExternalPlayerStore? _readExternalPlayerStore(BuildContext context) {
  try {
    return context.read<ExternalPlayerStore>();
  } on ProviderNotFoundException {
    return null;
  }
}

void _pushInAppPlayer(
  BuildContext context, {
  required String movieNumber,
  int? mediaId,
  int? positionSeconds,
}) {
  MobileMoviePlayerRouteData(
    movieNumber: movieNumber,
    mediaId: mediaId,
    positionSeconds: positionSeconds,
  ).push(context);
}

MovieMediaItemDto? _resolvePlayableMedia(MovieDetailDto? movie, int? mediaId) {
  if (movie == null) {
    return null;
  }
  if (mediaId != null) {
    for (final item in movie.mediaItems) {
      if (item.mediaId == mediaId && item.hasPlayableUrl) {
        return item;
      }
    }
  }
  for (final item in movie.mediaItems) {
    if (item.hasPlayableUrl) {
      return item;
    }
  }
  return null;
}
