import 'package:flutter/widgets.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/data/external_player_selection.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';
import 'package:sakuramedia/features/media/data/media_play_url_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';

/// 统一的影片播放入口：根据用户是否设置了默认外部播放器，决定跳应用内播放页
/// 还是直接拉起外部播放器。所有播放入口都应经由此函数，保证行为一致。
///
/// [movie] 可传入已加载的详情以避免重复请求（详情页场景）；缺省时按需拉取。
/// [playMode] 为 [MoviePlayUrlMode.merged] 时**只走外部播放器**（内置播放器不消费
/// 合并链接）：按 [playSource] 向后端解析合并播放链接后传给外部播放器；外部播放器
/// 不可用、解析失败或链接为空时回落到应用内单播。
Future<void> launchMoviePlayback(
  BuildContext context, {
  required String movieNumber,
  int? mediaId,
  int? positionSeconds,
  MovieDetailDto? movie,
  MoviePlayUrlSource? playSource,
  MoviePlayUrlMode playMode = MoviePlayUrlMode.single,
}) async {
  final selection = _readExternalPlayerSelection(context);
  const channel = ExternalPlayerChannel();
  final canUseExternal =
      selection != null && selection.hasExternalPlayer && channel.isSupported;

  if (playMode == MoviePlayUrlMode.merged) {
    if (!canUseExternal) {
      // 合并播放只走外部播放器，外部播放器不可用时回落到应用内单播并提示。
      showToast('合并播放不可用，已使用应用内播放');
      _pushInAppPlayer(
        context,
        movieNumber: movieNumber,
        mediaId: mediaId,
        positionSeconds: positionSeconds,
      );
      return;
    }
    await _launchExternalMergedPlayback(
      context,
      movieNumber: movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
      movie: movie,
      selection: selection,
      source: playSource ?? MoviePlayUrlSource.local,
    );
    return;
  }

  // 未设置外部播放器、当前平台不支持、或偏好未注入（如局部测试树），
  // 直接走应用内播放页。
  if (!canUseExternal) {
    _pushInAppPlayer(
      context,
      movieNumber: movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
    );
    return;
  }

  final packageName = selection.packageName!;

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
  final baseUrl =
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(sessionStoreProvider).baseUrl;
  final resolvedUrl =
      media == null
          ? null
          : resolveMediaUrl(
            rawUrl: resolveExternalPlayerSingleUrl(media),
            baseUrl: baseUrl,
          );

  // 拿不到可播放直链时回落到应用内播放页。
  if (detail == null ||
      media == null ||
      resolvedUrl == null ||
      resolvedUrl.isEmpty) {
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

/// 合并播放走外部播放器：调 `/media/play-url` 拿合并链接后拉起外部播放器。
Future<void> _launchExternalMergedPlayback(
  BuildContext context, {
  required String movieNumber,
  int? mediaId,
  int? positionSeconds,
  MovieDetailDto? movie,
  required ExternalPlayerSelection selection,
  required MoviePlayUrlSource source,
}) async {
  const channel = ExternalPlayerChannel();

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

  final title =
      (detail != null && detail.preferredTitle.isNotEmpty)
          ? detail.preferredTitle
          : movieNumber;

  MoviePlayUrlDto playUrl;
  try {
    playUrl = await ProviderScope.containerOf(context, listen: false)
        .read(mediaApiProvider)
        .getMoviePlayUrl(
          movieNumber: movieNumber,
          source: source,
          mode: MoviePlayUrlMode.merged,
        );
  } catch (_) {
    playUrl = const MoviePlayUrlDto(
      playUrl: null,
      kind: MoviePlayUrlKind.none,
      segmentCount: 0,
      segments: <MoviePlayUrlSegmentDto>[],
    );
  }
  if (!context.mounted) {
    return;
  }

  final baseUrl =
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(sessionStoreProvider).baseUrl;
  final resolvedUrl =
      playUrl.hasPlayableUrl
          ? resolveMediaUrl(rawUrl: playUrl.playUrl, baseUrl: baseUrl)
          : null;

  if (resolvedUrl == null || resolvedUrl.isEmpty) {
    showToast('合并播放暂不可用，已使用应用内播放');
    _pushInAppPlayer(
      context,
      movieNumber: movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
    );
    return;
  }

  // 拉起外部播放器前先探测合并流：规格不一致等校验在 merged-stream 端点进行，
  // 提前用 Range: bytes=0-0 触发，422/404 就直接提示用户，不跳外部播放器也不回退单播。
  final probeOk = await ProviderScope.containerOf(
    context,
    listen: false,
  ).read(mediaApiProvider).probeMergedPlayback(playUrl: playUrl.playUrl!);
  if (!context.mounted) {
    return;
  }
  if (!probeOk) {
    showToast('分段规格不一致，无法合并播放');
    return;
  }

  // 合并播放不传续播位置：逻辑文件跨多个分段，单段 stored progress 对不上。
  final launched = await channel.launch(
    packageName: selection.packageName!,
    url: resolvedUrl,
    title: title,
  );
  if (!context.mounted) {
    return;
  }
  if (!launched) {
    showToast('外部播放器不可用，已使用应用内播放');
    _pushInAppPlayer(
      context,
      movieNumber: movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
    );
  }
}

/// 安全读取偏好；树上没有 `ProviderScope` 的局部上下文（部分 widget 测试）
/// 或偏好尚未读完（AsyncValue 无值）返回 null（降级为应用内播放），与旧
/// `ProviderNotFoundException` / isLoaded=false 语义一致。
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

/// 外部播放器单播地址：115 媒体换成后端 HLS 代理的 `.m3u8`。
///
/// 签名载荷（`media:{id}:{expires}`）与路径后缀无关，把 `/stream` 换成
/// `/stream.m3u8` 后原签名仍有效；http 部署下 ExoPlayer 系播放器不跟随
/// http->https 的 302 跳转，且需要 `.m3u8` 后缀才能按 HLS 解析，故 115 源
/// 必须走代理。本地媒体保持原 `/stream` 字节流。
@visibleForTesting
String resolveExternalPlayerSingleUrl(MovieMediaItemDto media) {
  if (!media.isCloud115) {
    return media.playUrl;
  }
  return media.playUrl.replaceFirst('/stream?', '/stream.m3u8?');
}
