import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/actor_search_selection_controller.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_avatar.dart';

/// 影片演员选择弹层的固定主体高度，避免搜索状态切换时弹窗跳动。
const double actorPickerBodyHeight = 380;

enum _ActorPickerKind { movieCast, actorMerge }

/// 女优搜索框 + 结果列表 + 选中摘要的共享 leaf。
class ActorPickerResults extends StatelessWidget {
  const ActorPickerResults.movieCast({
    super.key,
    required this.controller,
    required this.existingActorIds,
    required this.onCreateLocalActor,
  }) : _kind = _ActorPickerKind.movieCast;

  const ActorPickerResults.actorMerge({super.key, required this.controller})
    : _kind = _ActorPickerKind.actorMerge,
      existingActorIds = const <int>{},
      onCreateLocalActor = null;

  final ActorSearchSelectionController controller;
  final Set<int> existingActorIds;
  final ValueChanged<String>? onCreateLocalActor;
  final _ActorPickerKind _kind;

  bool get _isMovieCast => _kind == _ActorPickerKind.movieCast;
  String get _keyPrefix => _isMovieCast ? 'movie-actor-picker' : 'actor-merge';

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final secondaryStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      tone: AppTextTone.secondary,
    );
    final column = Column(
      mainAxisSize: _isMovieCast ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          fieldKey: Key('$_keyPrefix-search-field'),
          controller: controller.searchController,
          label: _isMovieCast
              ? l10n.movieWidgetSearchActorLabel
              : l10n.actorMergeSearchLabel,
          hintText: _isMovieCast
              ? l10n.movieWidgetActorSearchHint
              : l10n.actorMergeSearchHint,
          textInputAction: TextInputAction.search,
          onChanged: controller.onQueryChanged,
          onFieldSubmitted: controller.submitSearch,
        ),
        SizedBox(height: spacing.md),
        if (_isMovieCast)
          Expanded(child: _buildResults(context, l10n))
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: _buildResults(context, l10n),
          ),
        if (controller.selectedCount > 0) ...[
          SizedBox(height: spacing.sm),
          Text(
            _buildSummary(l10n),
            key: Key('$_keyPrefix-selection-summary'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: secondaryStyle,
          ),
        ],
        if (controller.searchErrorMessage != null) ...[
          SizedBox(height: spacing.sm),
          Text(
            controller.searchErrorMessage!,
            key: Key('$_keyPrefix-search-error'),
            style: secondaryStyle,
          ),
        ],
      ],
    );
    if (!_isMovieCast) return column;
    return SizedBox(height: actorPickerBodyHeight, child: column);
  }

  String _buildSummary(AppLocalizations l10n) {
    final names = controller.selectedActors
        .map((actor) => actor.displayName)
        .join(
          _isMovieCast
              ? l10n.movieWidgetActorNameSeparator
              : l10n.listSeparator,
        );
    return _isMovieCast
        ? l10n.movieWidgetSelectedActorsSummary(controller.selectedCount, names)
        : l10n.actorMergeSelectedSummary(controller.selectedCount, names);
  }

  Widget _buildResults(BuildContext context, AppLocalizations l10n) {
    final spacing = context.appSpacing;
    if (controller.isSearching) {
      return const Center(child: AppPickerIosState(loading: true));
    }
    if (controller.searchErrorMessage != null) {
      return const SizedBox.shrink();
    }
    if (!controller.hasSearched) {
      if (!_isMovieCast) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          l10n.movieWidgetActorSearchPrompt,
          key: Key('$_keyPrefix-hint'),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
      );
    }
    if (controller.candidates.isEmpty) {
      final state = AppPickerIosState(
        key: Key('$_keyPrefix-empty'),
        message: _isMovieCast
            ? l10n.movieWidgetActorNotFound
            : l10n.actorMergeEmptyResult,
      );
      if (_createAction == null) return state;
      return AppPickerIosStateWithAction(
        state: state,
        action: AppPickerIosActionRow(
          label: l10n.movieWidgetCreateLocalActorWithName(controller.query),
          icon: Icons.person_add_alt_1_rounded,
          optionKey: Key('$_keyPrefix-create-entry'),
          onTap: () => _createAction!(controller.query),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: AppPickerIosSection(
              dividerIndent: 68,
              children: [
                for (final candidate in controller.candidates)
                  _buildRow(context, candidate, l10n),
              ],
            ),
          ),
        ),
        if (_createAction != null) ...[
          SizedBox(height: spacing.xs),
          AppTextButton(
            key: Key('$_keyPrefix-create-entry'),
            label: l10n.movieWidgetCreateLocalActorEntry,
            size: AppTextButtonSize.xSmall,
            emphasis: AppTextButtonEmphasis.accent,
            onPressed: () => _createAction!(controller.query),
          ),
        ],
      ],
    );
  }

  ValueChanged<String>? get _createAction =>
      _isMovieCast && controller.query.isNotEmpty ? onCreateLocalActor : null;

  Widget _buildRow(
    BuildContext context,
    ActorListItemDto candidate,
    AppLocalizations l10n,
  ) {
    final isExisting = existingActorIds.contains(candidate.id);
    final isSelected = controller.isSelected(candidate.id);
    return AppPickerIosRow(
      optionKey: Key('$_keyPrefix-candidate-${candidate.id}'),
      selected: isExisting || isSelected,
      showCheckmark: true,
      enabled: !isExisting,
      onTap: () => controller.toggle(candidate),
      title: candidate.displayName,
      leading: ActorAvatar(
        imageUrl: candidate.profileImage?.origin,
        size: context.appComponentTokens.iconSize2xl,
        placeholderKey: Key(
          _isMovieCast
              ? '$_keyPrefix-avatar-placeholder-${candidate.id}'
              : '$_keyPrefix-candidate-avatar-placeholder-${candidate.id}',
        ),
      ),
      subtitle: _isMovieCast && candidate.isLocal
          ? l10n.movieWidgetLocalActorBadge
          : candidate.javdbId,
      trailingText: isExisting ? l10n.movieWidgetActorAlreadyInCast : null,
    );
  }
}
