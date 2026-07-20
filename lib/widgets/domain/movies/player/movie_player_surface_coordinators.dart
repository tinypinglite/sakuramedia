import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/player/movie_player_subtitle_state.dart';

typedef MoviePlayerSurfaceSubtitleTextLoader = Future<String> Function(
    MoviePlayerSubtitleOption option);

typedef MoviePlayerSurfaceSetSubtitleTrack = Future<void> Function(
    SubtitleTrack track);

typedef MoviePlayerSurfaceOpen = Future<void> Function(
  String resolvedUrl, {
  required Duration? startPosition,
  required bool play,
});

typedef MoviePlayerSurfaceAction = Future<void> Function();

typedef MoviePlayerSurfaceSeek = Future<void> Function(Duration position);

class MoviePlayerSurfaceSubtitleCoordinator {
  const MoviePlayerSurfaceSubtitleCoordinator();

  Future<int?> applySelection({
    required MoviePlayerSurfaceSetSubtitleTrack setSubtitleTrack,
    required MoviePlayerSubtitleOption? selectedOption,
    required MoviePlayerSurfaceSubtitleTextLoader loadSubtitleText,
    required VoidCallback onError,
  }) async {
    try {
      if (selectedOption == null) {
        debugPrint('[player-debug] subtitle_apply_begin mode=off');
        await setSubtitleTrack(SubtitleTrack.no());
        debugPrint('[player-debug] subtitle_apply_success mode=off');
        return null;
      }
      debugPrint(
        '[player-debug] subtitle_apply_begin mode=select subtitleId=${selectedOption.subtitleId} url=${selectedOption.resolvedUrl} title=${selectedOption.title}',
      );
      final subtitleText = await loadSubtitleText(selectedOption);
      debugPrint(
        '[player-debug] subtitle_apply_loaded subtitleId=${selectedOption.subtitleId} textLength=${subtitleText.length}',
      );
      await setSubtitleTrack(
        SubtitleTrack.data(
          subtitleText,
          title: selectedOption.title,
          language: selectedOption.language,
        ),
      );
      debugPrint(
        '[player-debug] subtitle_apply_success mode=select subtitleId=${selectedOption.subtitleId}',
      );
      return selectedOption.subtitleId;
    } catch (error) {
      debugPrint('[player-debug] subtitle_apply_error error=$error');
      try {
        await setSubtitleTrack(SubtitleTrack.no());
        debugPrint('[player-debug] subtitle_apply_fallback mode=off');
      } catch (_) {
        // Keep the original failure as the user-visible signal.
      }
      onError();
      return null;
    }
  }
}

class MoviePlayerSurfaceOpenCoordinator {
  const MoviePlayerSurfaceOpenCoordinator();

  Future<void> open({
    required MoviePlayerSurfaceOpen open,
    required MoviePlayerSurfaceAction play,
    required MoviePlayerSurfaceSeek seek,
    required MoviePlayerSurfaceAction waitUntilFirstFrameRendered,
    required String resolvedUrl,
    required Duration? initialPosition,
    required bool Function() shouldContinue,
    required VoidCallback markReady,
    Future<void> Function()? waitUntilSeekReady,
  }) async {
    final startupPosition =
        initialPosition != null && initialPosition > Duration.zero
            ? initialPosition
            : null;
    debugPrint(
      '[player-debug] surface_open_begin url=$resolvedUrl initialPositionSeconds=${initialPosition?.inSeconds} startupPositionSeconds=${startupPosition?.inSeconds}',
    );
    final openPosition = waitUntilSeekReady == null ? startupPosition : null;
    await open(resolvedUrl, startPosition: openPosition, play: false);
    if (!shouldContinue()) {
      debugPrint('[player-debug] surface_open_abort_after=open');
      return;
    }

    debugPrint('[player-debug] surface_open_step=play');
    await play();
    if (!shouldContinue()) {
      debugPrint('[player-debug] surface_open_abort_after=play');
      return;
    }

    debugPrint('[player-debug] surface_open_step=wait_first_frame');
    await waitUntilFirstFrameRendered();
    if (!shouldContinue()) {
      debugPrint('[player-debug] surface_open_abort_after=wait_first_frame');
      return;
    }

    if (waitUntilSeekReady != null) {
      debugPrint('[player-debug] surface_open_step=wait_seek_ready');
      await waitUntilSeekReady();
      if (!shouldContinue()) {
        debugPrint('[player-debug] surface_open_abort_after=wait_seek_ready');
        return;
      }
    }

    if (startupPosition != null) {
      debugPrint(
        '[player-debug] surface_open_step=seek startupPositionSeconds=${startupPosition.inSeconds}',
      );
      await seek(startupPosition);
      if (!shouldContinue()) {
        debugPrint('[player-debug] surface_open_abort_after=seek');
        return;
      }
    }

    debugPrint('[player-debug] surface_open_step=ready');
    markReady();
  }
}
