import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

/// 加载某切片预览帧（detail.preview_frames）的回调。
typedef PreviewFramesLoader = Future<List<MovieImageDto>> Function();

enum _ClipCardAction { addToCollection, rename, delete }

/// 切片网格卡：封面 + 标题 + 元信息；鼠标悬停时按需拉取预览帧并轮播成动态预览。
class ClipGridCard extends StatefulWidget {
  const ClipGridCard({
    super.key,
    required this.clip,
    required this.onPlay,
    required this.onRename,
    required this.onDelete,
    required this.onAddToCollection,
    required this.loadPreviewFrames,
  });

  final MediaClipDto clip;
  final VoidCallback onPlay;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onAddToCollection;
  final PreviewFramesLoader loadPreviewFrames;

  @override
  State<ClipGridCard> createState() => _ClipGridCardState();
}

class _ClipGridCardState extends State<ClipGridCard> {
  /// 轮播节奏与抽样上限：预览帧可能多达数十张，均匀抽样并控制节奏避免卡顿与过长循环。
  static const Duration _frameInterval = Duration(milliseconds: 400);
  static const int _maxFrames = 24;

  List<MovieImageDto> _frames = const <MovieImageDto>[];
  bool _isLoadingFrames = false;
  bool _framesLoaded = false;
  bool _hovering = false;
  int _frameIndex = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onEnter() {
    _hovering = true;
    if (_framesLoaded) {
      _startCycling();
    } else {
      _loadFrames();
    }
  }

  void _onExit() {
    _hovering = false;
    _timer?.cancel();
    _timer = null;
    if (_frameIndex != 0) {
      setState(() => _frameIndex = 0);
    }
  }

  Future<void> _loadFrames() async {
    if (_isLoadingFrames || _framesLoaded) {
      return;
    }
    _isLoadingFrames = true;
    try {
      final frames = await widget.loadPreviewFrames();
      if (!mounted) {
        return;
      }
      _frames = _sampleFrames(frames);
      _framesLoaded = true;
      if (_hovering) {
        _startCycling();
      }
    } catch (_) {
      // 预览帧加载失败时静默降级为静态封面，不打扰用户。
    } finally {
      _isLoadingFrames = false;
    }
  }

  static List<MovieImageDto> _sampleFrames(List<MovieImageDto> frames) {
    if (frames.length <= _maxFrames) {
      return frames;
    }
    final step = frames.length / _maxFrames;
    return List<MovieImageDto>.generate(
      _maxFrames,
      (i) => frames[(i * step).floor().clamp(0, frames.length - 1)],
    );
  }

  void _startCycling() {
    if (_frames.length < 2) {
      return;
    }
    _timer?.cancel();
    _timer = Timer.periodic(_frameInterval, (_) {
      if (!mounted || !_hovering) {
        return;
      }
      setState(() => _frameIndex = (_frameIndex + 1) % _frames.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final clip = widget.clip;
    final coverUrl = clip.coverImage?.bestAvailableUrl;
    final title = clip.title.trim();
    final showFrame =
        _hovering && _frames.isNotEmpty && _frameIndex < _frames.length;
    final frameUrl = showFrame ? _frames[_frameIndex].bestAvailableUrl : null;

    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      child: Material(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        child: InkWell(
          key: Key('clip-grid-card-tap-${clip.clipId}'),
          borderRadius: context.appRadius.mdBorder,
          onTap: widget.onPlay,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: context.appRadius.mdBorder,
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(context.appRadius.md),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (frameUrl != null && frameUrl.isNotEmpty)
                          MaskedImage(
                            key: ValueKey<String>('frame-$frameUrl'),
                            url: frameUrl,
                            fit: BoxFit.cover,
                          )
                        else if (coverUrl != null && coverUrl.isNotEmpty)
                          MaskedImage(url: coverUrl, fit: BoxFit.cover)
                        else
                          ColoredBox(color: colors.surfaceMuted),
                        if (!showFrame) const _PlayOverlay(),
                        Positioned(
                          right: spacing.xs,
                          bottom: spacing.xs,
                          child: _DurationBadge(
                            seconds: clip.durationSeconds,
                          ),
                        ),
                        Positioned(
                          right: spacing.xs,
                          top: spacing.xs,
                          child: _ClipMenu(
                            menuKey: Key('clip-grid-menu-${clip.clipId}'),
                            onAddToCollection: widget.onAddToCollection,
                            onRename: widget.onRename,
                            onDelete: widget.onDelete,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(spacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? '未命名切片' : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          weight: AppTextWeight.semibold,
                          tone: AppTextTone.primary,
                        ),
                      ),
                      SizedBox(height: spacing.xs),
                      Text(
                        clip.movieNumber?.isNotEmpty == true
                            ? clip.movieNumber!
                            : '无番号',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          weight: AppTextWeight.regular,
                          tone: AppTextTone.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayOverlay extends StatelessWidget {
  const _PlayOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.16)),
      child: Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: Colors.white.withValues(alpha: 0.92),
          size: context.appComponentTokens.iconSize2xl,
        ),
      ),
    );
  }
}

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: context.appRadius.xsBorder,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.appSpacing.xs,
          vertical: context.appSpacing.xs,
        ),
        child: Text(
          formatMediaTimecode(seconds),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: AppTextTone.primary,
          ).copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _ClipMenu extends StatelessWidget {
  const _ClipMenu({
    required this.menuKey,
    required this.onAddToCollection,
    required this.onRename,
    required this.onDelete,
  });

  final Key menuKey;
  final VoidCallback onAddToCollection;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<_ClipCardAction>(
        key: menuKey,
        tooltip: '更多',
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        icon: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.more_horiz_rounded, color: Colors.white, size: 18),
        ),
        onSelected: (action) {
          switch (action) {
            case _ClipCardAction.addToCollection:
              onAddToCollection();
            case _ClipCardAction.rename:
              onRename();
            case _ClipCardAction.delete:
              onDelete();
          }
        },
        itemBuilder:
            (context) => const <PopupMenuEntry<_ClipCardAction>>[
              PopupMenuItem<_ClipCardAction>(
                value: _ClipCardAction.addToCollection,
                child: Text('加入合集'),
              ),
              PopupMenuItem<_ClipCardAction>(
                value: _ClipCardAction.rename,
                child: Text('重命名'),
              ),
              PopupMenuItem<_ClipCardAction>(
                value: _ClipCardAction.delete,
                child: Text('删除'),
              ),
            ],
      ),
    );
  }
}
