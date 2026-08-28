import 'package:flutter/widgets.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/data/external_player_selection.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';

/// 统一的影片播放入口：根据用户是否设置了默认外部播放器，决定跳应用内播放页
/// 还是直接拉起外部播放器。
///
/// 详情接口返回的 [MovieMediaItemDto.playUrl] 已经是后端签名播放地址。前端只
/// 负责把相对地址补成完整 URL，不再探测、拼接或转换播放流。
Future<void> launchMoviePlayback(
  BuildContext context, {
  required String movieNumber,
  int? mediaId,
  int? positionSeconds,
  MovieDetailDto? movie,
  MoviePlaybackDelivery? playbackDelivery,
}) async {
  final selection = _readExternalPlayerSelection(context);
  const channel = ExternalPlayerChannel();
  final canUseExternal =
      selection != null && selection.hasExternalPlayer && channel.isSupported;

  if (!canUseExternal) {
    _pushInAppPlayer(
      context,
      movieNumber: movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
      playbackDelivery: playbackDelivery,
    );
    return;
  }

  // 外部播放器需要完整直链与标题，按需补齐影片详情。
  var detail = movie;
  if (detail == null) {
    try {
      detail = await ProviderScope.containerOf(
        context,
        listen: false,
      ).read(moviesApiProvider).getMovieDetail(movieNumber: movieNumber);
    } catch (_) {
      detail = null;
    }
    if (!context.mounted) {
      return;
    }
  }

  final media = _resolvePlayableMedia(detail, mediaId);
  final baseUrl = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(sessionStoreProvider).baseUrl;
  final resolvedUrl = media == null
      ? null
      : resolveMediaUrl(
          rawUrl: withMoviePlaybackDelivery(
            media.playUrl,
            playbackDelivery ?? media.defaultPlaybackDelivery,
          ),
          baseUrl: baseUrl,
        );

  // 拿不到后端签名播放地址时回落到应用内播放页。
  if (detail == null ||
      media == null ||
      resolvedUrl == null ||
      resolvedUrl.isEmpty) {
    _pushInAppPlayer(
      context,
      movieNumber: movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
      playbackDelivery: playbackDelivery,
    );
    return;
  }

  final resumeSeconds =
      positionSeconds ?? media.progress?.lastPositionSeconds ?? 0;
  final title = detail.preferredTitle.isNotEmpty
      ? detail.preferredTitle
      : movieNumber;

  final launched = await channel.launch(
    packageName: selection.packageName!,
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
      playbackDelivery: playbackDelivery,
    );
  }
}

/// 安全读取偏好；树上没有 [ProviderScope] 的局部上下文（部分 widget 测试）
/// 或偏好尚未读完返回 null（降级为应用内播放）。
ExternalPlayerSelection? _readExternalPlayerSelection(BuildContext context) {
  try {
    return ProviderScope.containerOf(
      context,
      listen: false,
    ).read(externalPlayerPreferenceProvider).value;
  } on Object {
    return null;
  }
}

void _pushInAppPlayer(
  BuildContext context, {
  required String movieNumber,
  int? mediaId,
  int? positionSeconds,
  MoviePlaybackDelivery? playbackDelivery,
}) {
  MobileMoviePlayerRouteData(
    movieNumber: movieNumber,
    mediaId: mediaId,
    positionSeconds: positionSeconds,
    delivery: playbackDelivery?.wireValue,
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
