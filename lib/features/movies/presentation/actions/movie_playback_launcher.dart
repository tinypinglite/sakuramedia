import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:sakuramedia/core/media/media_url_resolver.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/features/external_player/data/external_player_channel.dart';
import 'package:sakuramedia/features/external_player/data/external_player_selection.dart';
import 'package:sakuramedia/features/external_player/presentation/providers/external_player_preference_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/desktop_routes.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';

/// 统一的影片播放入口：根据用户是否设置了默认外部播放器，决定跳应用内播放页
/// 还是直接拉起外部播放器。
///
/// 详情接口返回的 [MovieMediaItemDto.playUrl] 已经是后端签名播放地址。前端只
/// 负责补全 URL，外部播放器通道按用户偏好选择传输方式。
Future<void> launchMoviePlayback(
  BuildContext context, {
  required String movieNumber,
  int? mediaId,
  int? positionSeconds,
  MovieDetailDto? movie,
  String? inAppFallbackPath,
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
      fallbackPath: inAppFallbackPath,
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
      : resolveMediaUrl(rawUrl: media.playUrl, baseUrl: baseUrl);

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
      fallbackPath: inAppFallbackPath,
    );
    return;
  }

  final resumeSeconds =
      positionSeconds ?? media.progress?.lastPositionSeconds ?? 0;
  final title = detail.preferredTitle.isNotEmpty
      ? detail.preferredTitle
      : movieNumber;

  final launched = await channel.launch(
    playerId: selection.playerId!,
    url: resolvedUrl,
    playbackMode: selection.playbackMode,
    title: title,
    positionMs: resumeSeconds > 0 ? resumeSeconds * 1000 : null,
  );
  if (!context.mounted) {
    return;
  }
  if (!launched) {
    // 外部播放器不可用（可能已卸载），提示并回落到应用内播放。
    showToast(
      AppLocalizations.of(context).movieActionExternalPlayerUnavailableInApp,
      tone: AppToastTone.error,
    );
    _pushInAppPlayer(
      context,
      movieNumber: movieNumber,
      mediaId: mediaId,
      positionSeconds: positionSeconds,
      fallbackPath: inAppFallbackPath,
    );
  }
}

/// 外部播放器使用后端合并地址；内置播放器按同库媒体顺序连播。
Future<void> launchMovieMergedPlayback(
  BuildContext context, {
  required String movieNumber,
  required int libraryId,
  MovieDetailDto? movie,
}) async {
  final selection = _readExternalPlayerSelection(context);
  const channel = ExternalPlayerChannel();
  if (selection == null ||
      !selection.hasExternalPlayer ||
      !channel.isSupported) {
    _pushInAppPlayer(
      context,
      movieNumber: movieNumber,
      mergedLibraryId: libraryId,
    );
    return;
  }

  try {
    final container = ProviderScope.containerOf(context, listen: false);
    final mergedPlayback = await container
        .read(moviesApiProvider)
        .getMergedPlayback(movieNumber: movieNumber, libraryId: libraryId);
    if (!context.mounted) {
      return;
    }
    final resolvedUrl = resolveMediaUrl(
      rawUrl: mergedPlayback.playUrl,
      baseUrl: container.read(sessionStoreProvider).baseUrl,
    );
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      showToast(
        AppLocalizations.of(context).movieActionMergedPlaybackUrlUnavailable,
        tone: AppToastTone.error,
      );
      return;
    }
    final title = movie?.preferredTitle.trim() ?? '';
    final launched = await channel.launch(
      playerId: selection.playerId!,
      url: resolvedUrl,
      title: title.isEmpty ? movieNumber : title,
    );
    if (context.mounted && !launched) {
      showToast(
        AppLocalizations.of(context).movieActionExternalPlayerUnavailable,
        tone: AppToastTone.error,
      );
    }
  } catch (error) {
    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.movieActionMergedPlaybackStartFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
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
  int? mergedLibraryId,
  int? positionSeconds,
  String? fallbackPath,
}) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      context.pushDesktopMoviePlayer(
        movieNumber: movieNumber,
        fallbackPath:
            fallbackPath ??
            DesktopMovieDetailRouteData(movieNumber: movieNumber).location,
        mediaId: mediaId,
        mergedLibraryId: mergedLibraryId,
        positionSeconds: positionSeconds,
      );
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      MobileMoviePlayerRouteData(
        movieNumber: movieNumber,
        mediaId: mediaId,
        mergedLibraryId: mergedLibraryId,
        positionSeconds: positionSeconds,
      ).push(context);
  }
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
