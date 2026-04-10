import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/presentation/movie_player_subtitle_state.dart';
import 'package:sakuramedia/theme.dart';

const double _subtitleMenuWidth = 188;
const double _subtitleMenuItemHeight = 38;
const EdgeInsets _subtitleMenuItemPadding = EdgeInsets.symmetric(
  horizontal: 12,
);

class MoviePlayerSubtitleButton extends StatelessWidget {
  const MoviePlayerSubtitleButton({
    super.key,
    required this.subtitleStateListenable,
    required this.isApplyingListenable,
    required this.onSubtitleSelected,
    required this.onReloadRequested,
  });

  final ValueListenable<MoviePlayerSubtitleState> subtitleStateListenable;
  final ValueListenable<bool> isApplyingListenable;
  final Future<void> Function(int? subtitleId) onSubtitleSelected;
  final Future<void> Function() onReloadRequested;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MoviePlayerSubtitleState>(
      valueListenable: subtitleStateListenable,
      builder: (context, subtitleState, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: isApplyingListenable,
          builder: (context, isApplying, child) {
            final componentTokens = context.appComponentTokens;
            return Builder(
              builder:
                  (buttonContext) => IconButton(
                    key: const Key('movie-player-subtitle-button'),
                    tooltip: '字幕',
                    visualDensity: VisualDensity.compact,
                    splashRadius: 18,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                    onPressed:
                        isApplying
                            ? null
                            : () => unawaited(
                              _showSubtitleMenu(
                                buttonContext,
                                subtitleState,
                                isApplying,
                              ),
                            ),
                    icon: Icon(
                      subtitleState.selectedSubtitleId == null
                          ? Icons.subtitles_outlined
                          : Icons.subtitles_rounded,
                      color: Colors.white,
                      size: componentTokens.iconSizeLg,
                    ),
                  ),
            );
          },
        );
      },
    );
  }

  Future<void> _showSubtitleMenu(
    BuildContext buttonContext,
    MoviePlayerSubtitleState subtitleState,
    bool isApplying,
  ) async {
    _logMenuOpened(subtitleState, isApplying);
    final navigator = Navigator.of(buttonContext);
    final overlay = navigator.overlay?.context.findRenderObject() as RenderBox?;
    final button = buttonContext.findRenderObject() as RenderBox?;
    if (overlay == null || button == null) {
      debugPrint(
        '[player-debug] subtitle_menu_aborted reason=missing_render_box',
      );
      return;
    }

    final buttonTopLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final buttonRect = buttonTopLeft & button.size;
    final position = RelativeRect.fromRect(
      buttonRect,
      Offset.zero & overlay.size,
    );

    final action = await showMenu<_MoviePlayerSubtitleMenuAction>(
      context: buttonContext,
      position: position,
      useRootNavigator: false,
      color: Theme.of(buttonContext).appColors.surfaceCard,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Theme.of(buttonContext).appColors.borderSubtle),
      ),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      constraints: const BoxConstraints.tightFor(width: _subtitleMenuWidth),
      items: _buildMenuEntries(subtitleState, isApplying),
    );

    if (action == null) {
      _logMenuCanceled(subtitleState, isApplying);
      return;
    }

    debugPrint(
      '[player-debug] subtitle_menu_selected action=${action.type.name} subtitleId=${action.subtitleId} selected=${subtitleState.selectedSubtitleId} options=${subtitleState.options.map((item) => item.subtitleId).join(",")}',
    );

    switch (action.type) {
      case _MoviePlayerSubtitleMenuActionType.off:
        await onSubtitleSelected(null);
        break;
      case _MoviePlayerSubtitleMenuActionType.select:
        if (action.subtitleId != null) {
          await onSubtitleSelected(action.subtitleId);
        }
        break;
      case _MoviePlayerSubtitleMenuActionType.retry:
        await onReloadRequested();
        break;
    }
  }

  void _logMenuOpened(MoviePlayerSubtitleState subtitleState, bool isApplying) {
    debugPrint(
      '[player-debug] subtitle_menu_opened selected=${subtitleState.selectedSubtitleId} isLoading=${subtitleState.isLoading} isApplying=$isApplying fetchStatus=${subtitleState.fetchStatus} error=${subtitleState.errorMessage} options=${subtitleState.options.map((item) => "${item.subtitleId}:${item.label}").join("|")}',
    );
  }

  void _logMenuCanceled(
    MoviePlayerSubtitleState subtitleState,
    bool isApplying,
  ) {
    debugPrint(
      '[player-debug] subtitle_menu_canceled selected=${subtitleState.selectedSubtitleId} isLoading=${subtitleState.isLoading} isApplying=$isApplying',
    );
  }

  List<PopupMenuEntry<_MoviePlayerSubtitleMenuAction>> _buildMenuEntries(
    MoviePlayerSubtitleState subtitleState,
    bool isApplying,
  ) {
    final entries = <PopupMenuEntry<_MoviePlayerSubtitleMenuAction>>[
      PopupMenuItem<_MoviePlayerSubtitleMenuAction>(
        key: const Key('movie-player-subtitle-menu-off'),
        value: const _MoviePlayerSubtitleMenuAction.off(),
        height: _subtitleMenuItemHeight,
        padding: _subtitleMenuItemPadding,
        child: _MoviePlayerSubtitleMenuRow(
          label: '关闭字幕',
          checked: subtitleState.selectedSubtitleId == null,
        ),
      ),
    ];

    if (isApplying || subtitleState.isLoading) {
      entries.add(
        const PopupMenuItem<_MoviePlayerSubtitleMenuAction>(
          key: Key('movie-player-subtitle-menu-loading'),
          enabled: false,
          height: _subtitleMenuItemHeight,
          padding: _subtitleMenuItemPadding,
          child: SizedBox(width: _subtitleMenuWidth - 24, child: Text('字幕加载中')),
        ),
      );
      return entries;
    }

    if (subtitleState.options.isNotEmpty) {
      entries.add(const PopupMenuDivider(height: 8));
      for (final option in subtitleState.options) {
        entries.add(
          PopupMenuItem<_MoviePlayerSubtitleMenuAction>(
            key: Key('movie-player-subtitle-menu-item-${option.subtitleId}'),
            value: _MoviePlayerSubtitleMenuAction.select(option.subtitleId),
            height: _subtitleMenuItemHeight,
            padding: _subtitleMenuItemPadding,
            child: _MoviePlayerSubtitleMenuRow(
              label: option.label,
              checked: subtitleState.selectedSubtitleId == option.subtitleId,
            ),
          ),
        );
      }
      return entries;
    }

    final statusLabel = _statusLabel(subtitleState);
    if (statusLabel != null) {
      entries.add(
        PopupMenuItem<_MoviePlayerSubtitleMenuAction>(
          key: const Key('movie-player-subtitle-menu-status'),
          enabled: false,
          height: _subtitleMenuItemHeight,
          padding: _subtitleMenuItemPadding,
          child: SizedBox(
            width: _subtitleMenuWidth - 24,
            child: Text(
              statusLabel,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      );
    }

    if (_canRetry(subtitleState)) {
      entries.add(
        const PopupMenuItem<_MoviePlayerSubtitleMenuAction>(
          key: Key('movie-player-subtitle-menu-retry'),
          value: _MoviePlayerSubtitleMenuAction.retry(),
          height: _subtitleMenuItemHeight,
          padding: _subtitleMenuItemPadding,
          child: SizedBox(
            width: _subtitleMenuWidth - 24,
            child: Text('重新加载字幕'),
          ),
        ),
      );
    }

    return entries;
  }

  bool _canRetry(MoviePlayerSubtitleState subtitleState) =>
      subtitleState.errorMessage != null ||
      subtitleState.fetchStatus == 'failed';

  String? _statusLabel(MoviePlayerSubtitleState subtitleState) {
    if (subtitleState.errorMessage != null) {
      return subtitleState.errorMessage;
    }

    switch (subtitleState.fetchStatus) {
      case 'pending':
        return '字幕待抓取';
      case 'running':
        return '字幕抓取中';
      case 'failed':
        return '字幕抓取失败';
      default:
        return '暂无字幕';
    }
  }
}

enum _MoviePlayerSubtitleMenuActionType { off, select, retry }

class _MoviePlayerSubtitleMenuAction {
  const _MoviePlayerSubtitleMenuAction._({required this.type, this.subtitleId});

  const _MoviePlayerSubtitleMenuAction.off()
    : this._(type: _MoviePlayerSubtitleMenuActionType.off);

  const _MoviePlayerSubtitleMenuAction.select(int subtitleId)
    : this._(
        type: _MoviePlayerSubtitleMenuActionType.select,
        subtitleId: subtitleId,
      );

  const _MoviePlayerSubtitleMenuAction.retry()
    : this._(type: _MoviePlayerSubtitleMenuActionType.retry);

  final _MoviePlayerSubtitleMenuActionType type;
  final int? subtitleId;
}

class _MoviePlayerSubtitleMenuRow extends StatelessWidget {
  const _MoviePlayerSubtitleMenuRow({
    required this.label,
    required this.checked,
  });

  final String label;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: checked ? FontWeight.w600 : null,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: componentTokens.iconSizeSm,
          child:
              checked
                  ? Icon(
                    Icons.check,
                    size: componentTokens.iconSizeSm,
                    color: Theme.of(context).colorScheme.onSurface,
                  )
                  : null,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: _subtitleMenuWidth - 24 - 18 - 8,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: textStyle,
          ),
        ),
      ],
    );
  }
}
