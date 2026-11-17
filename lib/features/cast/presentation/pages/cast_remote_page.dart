import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/cast/data/cast_remote_controller.dart';
import 'package:sakuramedia/features/cast/data/cast_session.dart';
import 'package:sakuramedia/features/cast/data/cast_transport.dart';
import 'package:sakuramedia/features/cast/presentation/providers/cast_remote_thumbnails_provider.dart';
import 'package:sakuramedia/features/cast/presentation/providers/cast_session_provider.dart';
import 'package:sakuramedia/features/cast/presentation/widgets/cast_remote_progress_bar.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/navigation/app_back_button.dart';
import 'package:sakuramedia/widgets/domain/media/movie_player_thumbnail_panel.dart';

/// 投屏遥控页：进度同步 + 播放控制 + 缩略图浏览/点击跳转。
///
/// 页面自身只负责遥控交互；会话信息由 [castSessionControllerProvider]
/// 保留，退出页面后电视继续播放，可从详情页菜单重新进入。
class CastRemotePage extends ConsumerStatefulWidget {
  const CastRemotePage({super.key, this.controllerFactory});

  /// 测试注入用；默认按会话组装真实控制器。
  final CastRemoteController Function(CastSession session)? controllerFactory;

  @override
  ConsumerState<CastRemotePage> createState() => _CastRemotePageState();
}

class _CastRemotePageState extends ConsumerState<CastRemotePage> {
  CastRemoteController? _controller;
  int? _columns;
  bool _scrollLocked = true;
  Duration? _previewPosition;

  @override
  void initState() {
    super.initState();
    final session = ref.read(castSessionControllerProvider);
    if (session == null) {
      return;
    }
    CastRemoteController? controller;
    try {
      controller =
          widget.controllerFactory?.call(session) ??
          _buildDefaultController(session);
    } on Object {
      // 设备句柄异常（理论上不会发生，投送成功即校验过）。
      controller = null;
    }
    if (controller != null) {
      _controller = controller;
      controller.start();
    }
  }

  CastRemoteController _buildDefaultController(CastSession session) {
    final mediaApi = ref.read(mediaApiProvider);
    return CastRemoteController(
      session: session,
      transport: UpnpCastTransport(session.device),
      l10n: () => ref.read(appLocalizationsProvider),
      reportProgress:
          ({required int mediaId, required int positionSeconds}) async {
            await mediaApi.updateMediaProgress(
              mediaId: mediaId,
              positionSeconds: positionSeconds,
            );
          },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _disconnect() async {
    final controller = _controller;
    if (controller != null) {
      await controller.stopPlayback();
    }
    ref.read(castSessionControllerProvider.notifier).clear();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(castSessionControllerProvider);
    final controller = _controller;
    if (session == null || controller == null) {
      return Scaffold(body: SafeArea(child: _buildEndedState(context)));
    }
    final thumbnailsAsync = ref.watch(
      castRemoteThumbnailsProvider(mediaId: session.mediaId),
    );
    final thumbnails =
        thumbnailsAsync.value ?? const <MovieMediaThumbnailDto>[];
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final state = controller.state;
            final displayPosition = _previewPosition ?? state.position;
            return Column(
              children: [
                _CastRemoteTopBar(
                  deviceName: session.device.name,
                  phase: state.phase,
                  onBack: () => Navigator.of(context).pop(),
                  onDisconnect: _disconnect,
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.appSpacing.lg,
                            ),
                            child: _buildProgressRow(
                              context,
                              controller,
                              state,
                              displayPosition,
                            ),
                          ),
                          SizedBox(height: context.appSpacing.xs),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.appSpacing.lg,
                            ),
                            child: _buildControlRow(context, controller, state),
                          ),
                          if (state.errorMessage != null)
                            Padding(
                              padding: EdgeInsets.only(
                                top: context.appSpacing.xs,
                                left: context.appSpacing.lg,
                                right: context.appSpacing.lg,
                              ),
                              child: Text(
                                state.errorMessage!,
                                style: resolveAppTextStyle(
                                  context,
                                  size: AppTextSize.s12,
                                  tone: AppTextTone.error,
                                ),
                              ),
                            ),
                          SizedBox(height: context.appSpacing.xs),
                          Expanded(
                            child: MoviePlayerThumbnailPanel(
                              thumbnails: thumbnails,
                              isLoading: thumbnailsAsync.isLoading,
                              errorMessage: thumbnailsAsync.hasError
                                  ? AppLocalizations.of(
                                      context,
                                    ).castThumbnailLoadFailed
                                  : null,
                              columns: _columns,
                              activeIndex: _resolveActiveIndex(
                                thumbnails,
                                displayPosition,
                              ),
                              isScrollLocked: _scrollLocked,
                              usesAutoColumns: _columns == null,
                              onColumnsChanged: (count) =>
                                  setState(() => _columns = count),
                              onToggleScrollLock: () => setState(
                                () => _scrollLocked = !_scrollLocked,
                              ),
                              onThumbnailTap: (index) {
                                setState(() => _previewPosition = null);
                                unawaited(
                                  controller.seekTo(
                                    Duration(
                                      seconds: thumbnails[index].offsetSeconds,
                                    ),
                                  ),
                                );
                              },
                              onRetry: () => ref.invalidate(
                                castRemoteThumbnailsProvider(
                                  mediaId: session.mediaId,
                                ),
                              ),
                              controlsAlignment: Alignment.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEndedState(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppEmptyState(
            icon: Icons.cast_connected_rounded,
            title: l10n.castEndedTitle,
            message: l10n.castEndedMessage,
          ),
          SizedBox(height: spacing.lg),
          AppButton(
            key: const Key('cast-remote-ended-back'),
            label: l10n.castBack,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow(
    BuildContext context,
    CastRemoteController controller,
    CastRemoteState state,
    Duration displayPosition,
  ) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final statusMessage = _statusMessageOf(state.phase, l10n);
    if (statusMessage != null) {
      return SizedBox(
        height: 28,
        child: Row(
          children: [
            if (state.phase == CastRemotePhase.connecting) ...[
              SizedBox.square(
                dimension: 14,
                child: const CircularProgressIndicator.adaptive(strokeWidth: 2),
              ),
              SizedBox(width: spacing.sm),
            ],
            Expanded(
              child: Text(
                statusMessage,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.secondary,
                ),
              ),
            ),
            if (state.phase == CastRemotePhase.disconnected)
              AppTextButton(
                key: const Key('cast-remote-retry'),
                label: l10n.commonRetry,
                size: AppTextButtonSize.small,
                onPressed: () => unawaited(controller.retry()),
              ),
            if (state.phase == CastRemotePhase.stopped ||
                state.phase == CastRemotePhase.finished)
              AppTextButton(
                key: const Key('cast-remote-restart'),
                label: l10n.castPlayAgain,
                size: AppTextButtonSize.small,
                onPressed: () => unawaited(controller.restartFromBeginning()),
              ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Expanded(
            child: CastRemoteProgressBar(
              key: const Key('cast-remote-progress'),
              position: state.position,
              duration: state.duration,
              enabled: state.isInteractive,
              onSeek: (target) {
                setState(() => _previewPosition = null);
                unawaited(controller.seekTo(target));
              },
              onPreview: (target) => setState(() => _previewPosition = target),
            ),
          ),
          SizedBox(width: spacing.sm),
          Text(
            '${formatMediaTimecode(displayPosition.inSeconds)}'
            ' / '
            '${formatMediaTimecode(state.duration.inSeconds)}',
            key: const Key('cast-remote-time'),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: state.isSeeking
                  ? AppTextTone.accent
                  : AppTextTone.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlRow(
    BuildContext context,
    CastRemoteController controller,
    CastRemoteState state,
  ) {
    final enabled = state.isInteractive;
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIconButton(
            key: const Key('cast-remote-back-10'),
            tooltip: l10n.castSeekBack10,
            onPressed: enabled
                ? () =>
                      unawaited(controller.seekBy(const Duration(seconds: -10)))
                : null,
            icon: const Icon(Icons.replay_10_rounded),
          ),
          SizedBox(width: spacing.xxl),
          AppIconButton(
            key: const Key('cast-remote-play-pause'),
            tooltip: state.isPlaying ? l10n.castPause : l10n.castPlay,
            onPressed: enabled
                ? () => unawaited(
                    state.isPlaying ? controller.pause() : controller.play(),
                  )
                : null,
            icon: Icon(
              state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
          ),
          SizedBox(width: spacing.xxl),
          AppIconButton(
            key: const Key('cast-remote-forward-10'),
            tooltip: l10n.castSeekForward10,
            onPressed: enabled
                ? () =>
                      unawaited(controller.seekBy(const Duration(seconds: 10)))
                : null,
            icon: const Icon(Icons.forward_10_rounded),
          ),
        ],
      ),
    );
  }
}

String? _statusMessageOf(CastRemotePhase phase, AppLocalizations l10n) {
  return switch (phase) {
    CastRemotePhase.connecting => l10n.castStatusConnecting,
    CastRemotePhase.disconnected => l10n.castStatusDisconnected,
    CastRemotePhase.stopped => l10n.castStatusStopped,
    CastRemotePhase.finished => l10n.castStatusFinished,
    _ => null,
  };
}

int? _resolveActiveIndex(
  List<MovieMediaThumbnailDto> thumbnails,
  Duration position,
) {
  if (thumbnails.isEmpty) {
    return null;
  }
  final seconds = position.inSeconds;
  var bestIndex = 0;
  var bestDiff = (thumbnails.first.offsetSeconds - seconds).abs();
  for (var index = 1; index < thumbnails.length; index++) {
    final diff = (thumbnails[index].offsetSeconds - seconds).abs();
    if (diff < bestDiff) {
      bestIndex = index;
      bestDiff = diff;
    }
  }
  return bestIndex;
}

class _CastRemoteTopBar extends StatelessWidget {
  const _CastRemoteTopBar({
    required this.deviceName,
    required this.phase,
    required this.onBack,
    required this.onDisconnect,
  });

  final String deviceName;
  final CastRemotePhase phase;
  final VoidCallback onBack;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final dotColor = switch (phase) {
      CastRemotePhase.playing || CastRemotePhase.paused =>
        resolveAppTextToneColor(context, AppTextTone.success),
      CastRemotePhase.connecting => context.appTextPalette.muted,
      _ => resolveAppTextToneColor(context, AppTextTone.error),
    };
    // macOS 的窗口交通灯悬浮在左上角，顶栏整行下移避让。
    final topInset = defaultTargetPlatform == TargetPlatform.macOS
        ? spacing.xl
        : spacing.xs;
    return Padding(
      padding: EdgeInsets.fromLTRB(spacing.xs, topInset, spacing.lg, 0),
      child: Row(
        children: [
          AppBackButton(
            key: const Key('cast-remote-back'),
            tooltip: l10n.castBack,
            size: AppBackButtonSize.touch,
            onPressed: onBack,
          ),
          SizedBox(width: spacing.xs),
          Container(
            key: const Key('cast-remote-status-dot'),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Text(
              l10n.castToDevice(deviceName),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.medium,
                tone: AppTextTone.primary,
              ),
            ),
          ),
          AppTextButton(
            key: const Key('cast-remote-disconnect'),
            label: l10n.castDisconnect,
            size: AppTextButtonSize.small,
            onPressed: () => unawaited(onDisconnect()),
          ),
        ],
      ),
    );
  }
}
