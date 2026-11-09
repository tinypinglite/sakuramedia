import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/movies/data/dto/detail/movie_detail_dto.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_actor_wrap.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_detail_section.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_detail_view_model.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

/// 影片详情页的演员区块：浏览态只读，进入管理态后可就地移除，并通过弹层添加。
class MovieActorSection extends StatefulWidget {
  const MovieActorSection({
    super.key,
    required this.actors,
    this.isActorsManuallyManaged = false,
    this.onActorTap,
    this.actorActions = const MovieDetailActorActions(),
  });

  final List<MovieActorDto> actors;
  final bool isActorsManuallyManaged;
  final ValueChanged<MovieActorDto>? onActorTap;

  final MovieDetailActorActions actorActions;

  @override
  State<MovieActorSection> createState() => _MovieActorSectionState();
}

class _MovieActorSectionState extends State<MovieActorSection> {
  bool _isEditing = false;
  bool _isAdding = false;
  final Set<int> _removingActorIds = <int>{};

  bool get _canManage => widget.actorActions.canManage;

  Future<void> _openPicker() async {
    if (!_canManage || _isAdding) {
      return;
    }
    final selected = await widget.actorActions.pickActors!(
      context,
      widget.actors.map((actor) => actor.id).toSet(),
    );
    if (!mounted || selected == null || selected.isEmpty) return;

    setState(() => _isAdding = true);
    var added = 0;
    var failed = 0;
    for (final actor in selected) {
      try {
        await widget.actorActions.addActor!(actor.id);
        added++;
      } catch (_) {
        failed++;
      }
    }

    final refreshed = await _notifyActorsChanged();
    if (!mounted) return;
    setState(() => _isAdding = false);
    final l10n = AppLocalizations.of(context);
    if (added == 0) {
      showToast(l10n.movieWidgetAddActorFailed, tone: AppToastTone.error);
    } else if (failed > 0) {
      showToast(
        l10n.movieWidgetActorsAddedWithFailures(added, failed),
        tone: AppToastTone.warning,
      );
    } else if (!refreshed) {
      showToast(
        l10n.movieWidgetActorsAddedRefreshFailed(added),
        tone: AppToastTone.warning,
      );
    } else if (added == 1) {
      showToast(
        l10n.movieWidgetActorAdded(selected.single.displayName),
        tone: AppToastTone.success,
      );
    } else {
      showToast(l10n.movieWidgetActorsAdded(added), tone: AppToastTone.success);
    }
  }

  Future<void> _removeActor(MovieActorDto actor) async {
    if (!_canManage) return;
    if (_removingActorIds.contains(actor.id)) return;

    setState(() => _removingActorIds.add(actor.id));
    try {
      await widget.actorActions.removeActor!(actor.id);
      final refreshed = await _notifyActorsChanged();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showToast(
        refreshed
            ? l10n.movieWidgetActorRemoved(actor.displayName)
            : l10n.movieWidgetActorRemovedRefreshFailed(actor.displayName),
        tone: refreshed ? AppToastTone.success : AppToastTone.error,
      );
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.movieWidgetRemoveActorFailed,
            l10n: l10n,
          ),
          tone: AppToastTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _removingActorIds.remove(actor.id));
      }
    }
  }

  Future<bool> _notifyActorsChanged() async {
    final refreshActors = widget.actorActions.refreshActors;
    if (refreshActors == null) return false;
    try {
      await refreshActors();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canManage && widget.actors.isEmpty) {
      return const SizedBox.shrink();
    }
    final spacing = context.appSpacing;
    final editing = _isEditing && _canManage;
    final l10n = AppLocalizations.of(context);
    return MovieDetailSection(
      title: l10n.movieWidgetActorsSectionTitle,
      titleKey: const Key('movie-actors-title'),
      trailing: _canManage ? _buildHeaderAction(context, editing) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MovieActorWrap(
            actors: widget.actors,
            onActorTap: editing ? null : widget.onActorTap,
            editing: editing,
            onRemoveTap: _removeActor,
            removingActorIds: _removingActorIds,
            trailing: editing
                ? _AddActorTile(
                    isLoading: _isAdding,
                    onTap: _isAdding ? null : _openPicker,
                  )
                : null,
          ),
          if (widget.isActorsManuallyManaged) ...[
            SizedBox(height: spacing.sm),
            _SectionHint(
              key: const Key('movie-actors-manual-notice'),
              text: editing
                  ? l10n.movieWidgetActorRemovalScopeNotice
                  : l10n.movieWidgetActorCastManualNotice,
            ),
          ] else if (editing) ...[
            SizedBox(height: spacing.sm),
            _SectionHint(
              key: const Key('movie-actors-edit-hint'),
              text: l10n.movieWidgetActorRemovalEditingHint,
            ),
          ] else if (widget.actors.isEmpty) ...[
            SizedBox(height: spacing.sm),
            _SectionHint(
              key: const Key('movie-actors-empty-hint'),
              text: l10n.movieWidgetActorAddManualHint,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderAction(BuildContext context, bool editing) {
    final l10n = AppLocalizations.of(context);
    if (editing) {
      return AppTextButton(
        key: const Key('movie-actors-finish-button'),
        label: l10n.commonDone,
        size: AppTextButtonSize.xSmall,
        onPressed: () => setState(() => _isEditing = false),
      );
    }
    if (widget.actors.isEmpty) {
      return AppTextButton(
        key: const Key('movie-actors-add-button'),
        label: l10n.movieWidgetAddActorTitle,
        size: AppTextButtonSize.xSmall,
        emphasis: AppTextButtonEmphasis.accent,
        isLoading: _isAdding,
        onPressed: _isAdding ? null : _openPicker,
      );
    }
    return AppTextButton(
      key: const Key('movie-actors-manage-button'),
      label: l10n.movieWidgetManageAction,
      size: AppTextButtonSize.xSmall,
      onPressed: () => setState(() => _isEditing = true),
    );
  }
}

class _SectionHint extends StatelessWidget {
  const _SectionHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.appSpacing.xs,
      runSpacing: context.appSpacing.xs,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: context.appComponentTokens.iconSizeXs,
          color: context.appTextPalette.muted,
        ),
        Text(
          text,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
      ],
    );
  }
}

class _AddActorTile extends StatelessWidget {
  const _AddActorTile({required this.isLoading, this.onTap});

  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final l10n = AppLocalizations.of(context);
    final tile = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: tokens.movieDetailActorAvatarSize,
          height: tokens.movieDetailActorAvatarSize,
          decoration: BoxDecoration(
            color: context.appColors.surfaceMuted,
            shape: BoxShape.circle,
            border: Border.all(color: context.appColors.borderSubtle),
          ),
          child: Center(
            child: isLoading
                ? AppInlineSpinner(color: context.appTextPalette.secondary)
                : Icon(
                    Icons.person_add_alt_1_rounded,
                    size: tokens.iconSizeSm,
                    color: context.appTextPalette.secondary,
                  ),
          ),
        ),
        SizedBox(height: spacing.sm),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: tokens.movieDetailActorCardWidth,
          ),
          child: Text(
            l10n.movieWidgetAddLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
        ),
      ],
    );

    final content = KeyedSubtree(
      key: const Key('movie-actor-add-tile'),
      child: tile,
    );
    if (onTap == null) {
      return Tooltip(message: l10n.movieWidgetAddActorTitle, child: content);
    }
    return Tooltip(
      message: l10n.movieWidgetAddActorTitle,
      child: AppInteractiveSurface(
        onTap: onTap,
        focusRingRadius: context.appRadius.mdBorder,
        child: content,
      ),
    );
  }
}
