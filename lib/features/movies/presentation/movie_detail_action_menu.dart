import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/movie_detail_action_copy.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';

enum MovieDetailActionType {
  toggleSubscription,
  refreshMetadata,
  recomputeHeat,
  syncInteraction,
  translateDescription,
}

class MovieDetailActionDescriptor {
  const MovieDetailActionDescriptor({
    required this.type,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.tone = AppTextTone.primary,
  });

  final MovieDetailActionType type;
  final String label;
  final IconData icon;
  final bool enabled;
  final AppTextTone tone;
}

List<MovieDetailActionDescriptor> buildMovieDetailActionDescriptors({
  required MovieDetailDto movie,
  required bool isSubscribed,
}) {
  final hasDescription = movie.desc.trim().isNotEmpty;
  final hasJavdbId = movie.javdbId.trim().isNotEmpty;

  return <MovieDetailActionDescriptor>[
    MovieDetailActionDescriptor(
      type: MovieDetailActionType.toggleSubscription,
      label: isSubscribed ? '取消订阅' : '订阅影片',
      icon:
          isSubscribed ? Icons.favorite_border_rounded : Icons.favorite_rounded,
      tone: isSubscribed ? AppTextTone.error : AppTextTone.primary,
    ),
    const MovieDetailActionDescriptor(
      type: MovieDetailActionType.refreshMetadata,
      label: '刷新元数据',
      icon: Icons.sync_rounded,
    ),
    const MovieDetailActionDescriptor(
      type: MovieDetailActionType.recomputeHeat,
      label: '计算热度',
      icon: Icons.local_fire_department_outlined,
    ),
    MovieDetailActionDescriptor(
      type: MovieDetailActionType.syncInteraction,
      label: '刷新互动数',
      icon: Icons.bar_chart_rounded,
      enabled: hasJavdbId,
    ),
    MovieDetailActionDescriptor(
      type: MovieDetailActionType.translateDescription,
      label: '翻译影片介绍',
      icon: Icons.translate_rounded,
      enabled: hasDescription,
    ),
  ];
}

Future<MovieDetailActionType?> showMovieDetailDesktopActionMenu({
  required BuildContext context,
  required Offset globalPosition,
  required List<MovieDetailActionDescriptor> actions,
}) {
  final colors = context.appColors;
  final spacing = context.appSpacing;
  final componentTokens = Theme.of(context).appComponentTokens;
  const menuItemHeight = 36.0;
  final navigator = Navigator.of(context);
  final overlay = navigator.overlay!.context.findRenderObject() as RenderBox;
  final localPosition = overlay.globalToLocal(globalPosition);
  final position = RelativeRect.fromRect(
    Rect.fromPoints(localPosition, localPosition),
    Offset.zero & overlay.size,
  );

  return showMenu<MovieDetailActionType>(
    context: context,
    position: position,
    useRootNavigator: false,
    color: colors.surfaceElevated,
    elevation: 12,
    shape: RoundedRectangleBorder(
      borderRadius: context.appRadius.lgBorder,
      side: BorderSide(color: colors.borderSubtle),
    ),
    items: actions
        .map(
          (action) => PopupMenuItem<MovieDetailActionType>(
            key: Key('movie-detail-hero-action-${action.type.name}'),
            value: action.type,
            enabled: action.enabled,
            height: menuItemHeight,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.sm,
              vertical: spacing.xs,
            ),
            child: Row(
              children: [
                Icon(
                  action.icon,
                  size: componentTokens.iconSizeXs,
                  color:
                      action.enabled
                          ? resolveAppTextToneColor(context, action.tone)
                          : context.appTextPalette.muted,
                ),
                SizedBox(width: spacing.sm),
                Text(
                  action.label,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: action.enabled ? action.tone : AppTextTone.muted,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList(growable: false),
  );
}

Future<void> showMovieDetailMobileActionDrawer({
  required BuildContext context,
  required String movieNumber,
  required List<MovieDetailActionDescriptor> actions,
  required Future<bool> Function(MovieDetailActionType action) onExecuteAction,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('movie-detail-actions-drawer'),
    maxHeightFactor: 0.64,
    builder:
        (drawerContext) => _MovieDetailActionDrawer(
          movieNumber: movieNumber,
          actions: actions,
          onExecuteAction: onExecuteAction,
        ),
  );
}

class _MovieDetailActionDrawer extends StatefulWidget {
  const _MovieDetailActionDrawer({
    required this.movieNumber,
    required this.actions,
    required this.onExecuteAction,
  });

  final String movieNumber;
  final List<MovieDetailActionDescriptor> actions;
  final Future<bool> Function(MovieDetailActionType action) onExecuteAction;

  @override
  State<_MovieDetailActionDrawer> createState() =>
      _MovieDetailActionDrawerState();
}

class _MovieDetailActionDrawerState extends State<_MovieDetailActionDrawer> {
  MovieDetailActionType? _pendingAction;
  bool _isConfirmingRefreshMetadata = false;

  bool get _isBusy => _pendingAction != null;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child:
          _isConfirmingRefreshMetadata
              ? _buildRefreshMetadataConfirmation(context)
              : Column(
                key: const Key('movie-detail-actions-list'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '影片操作',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s18,
                      weight: AppTextWeight.semibold,
                      tone: AppTextTone.primary,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    widget.movieNumber,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                  SizedBox(height: spacing.lg),
                  for (
                    var index = 0;
                    index < widget.actions.length;
                    index++
                  ) ...[
                    _MovieDetailDrawerActionRow(
                      key: Key(
                        'movie-detail-actions-${widget.actions[index].type.name}',
                      ),
                      icon: widget.actions[index].icon,
                      label: widget.actions[index].label,
                      tone: widget.actions[index].tone,
                      isEnabled: widget.actions[index].enabled && !_isBusy,
                      isLoading: _pendingAction == widget.actions[index].type,
                      onTap:
                          widget.actions[index].enabled && !_isBusy
                              ? () =>
                                  _handleActionTap(widget.actions[index].type)
                              : null,
                    ),
                    if (index != widget.actions.length - 1)
                      SizedBox(height: spacing.sm),
                  ],
                ],
              ),
    );
  }

  Widget _buildRefreshMetadataConfirmation(BuildContext context) {
    final spacing = context.appSpacing;

    return Column(
      key: const Key('movie-detail-refresh-metadata-confirmation'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          MovieDetailRefreshConfirmationCopy.title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          MovieDetailRefreshConfirmationCopy.description,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          MovieDetailRefreshConfirmationCopy.hint,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(height: spacing.xl),
        Row(
          children: [
            Expanded(
              child: AppButton(
                key: const Key('movie-detail-refresh-metadata-cancel'),
                label: MovieDetailRefreshConfirmationCopy.cancelLabel,
                onPressed:
                    _isBusy
                        ? null
                        : () {
                          setState(() {
                            _isConfirmingRefreshMetadata = false;
                          });
                        },
              ),
            ),
            SizedBox(width: spacing.md),
            Expanded(
              child: AppButton(
                key: const Key('movie-detail-refresh-metadata-confirm'),
                label: MovieDetailRefreshConfirmationCopy.confirmLabel,
                variant: AppButtonVariant.primary,
                isLoading:
                    _pendingAction == MovieDetailActionType.refreshMetadata,
                onPressed:
                    _isBusy
                        ? null
                        : () => _executeAction(
                          MovieDetailActionType.refreshMetadata,
                        ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleActionTap(MovieDetailActionType action) async {
    if (action == MovieDetailActionType.refreshMetadata) {
      setState(() {
        _isConfirmingRefreshMetadata = true;
      });
      return;
    }

    await _executeAction(action);
  }

  Future<void> _executeAction(MovieDetailActionType action) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _pendingAction = action;
    });

    final succeeded = await widget.onExecuteAction(action);
    if (!mounted) {
      return;
    }

    if (succeeded) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _pendingAction = null;
    });
  }
}

class _MovieDetailDrawerActionRow extends StatelessWidget {
  const _MovieDetailDrawerActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.isEnabled,
    required this.isLoading,
    required this.onTap,
    this.tone = AppTextTone.primary,
  });

  final IconData icon;
  final String label;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback? onTap;
  final AppTextTone tone;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final resolvedTone = isEnabled ? tone : AppTextTone.muted;
    final textColor = resolveAppTextToneColor(context, resolvedTone);

    return Opacity(
      opacity: isEnabled ? 1 : 0.56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: context.appRadius.lgBorder,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.md,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: context.appRadius.lgBorder,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: context.appComponentTokens.iconSizeMd,
                  color: textColor,
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      weight: AppTextWeight.medium,
                      tone: resolvedTone,
                    ),
                  ),
                ),
                if (isLoading)
                  SizedBox(
                    key: Key('movie-detail-actions-loading-$label'),
                    width: context.appComponentTokens.iconSizeMd,
                    height: context.appComponentTokens.iconSizeMd,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: context.appComponentTokens.iconSizeLg,
                    color: context.appTextPalette.muted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
