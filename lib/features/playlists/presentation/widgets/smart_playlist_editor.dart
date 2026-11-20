import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_actor_picker_sheet.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/smart_playlist_draft.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_provider.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_scope.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_chip.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_pill.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_avatar.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';
import 'package:sakuramedia/widgets/domain/tags/app_tag_match_mode_toggle.dart';
import 'package:sakuramedia/widgets/domain/tags/media_tag_filter_section.dart';
import 'package:sakuramedia/widgets/domain/tags/tag_filter_section.dart';

/// 智能列表的新建/编辑弹层。
///
/// 交互采用「分组卡片」：每个筛选维度一张卡片，多选维度在标题右侧提供
/// 「任一 / 全部」切换；保存后返回列表资源，写库、toast 与跨页广播由调用方负责。
Future<PlaylistDto?> showSmartPlaylistEditor(
  BuildContext context, {
  PlaylistDto? playlist,
}) {
  return showAppAdaptiveModal<PlaylistDto>(
    context: context,
    modalKey: const Key('smart-playlist-editor-modal'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    builder: (_) => SmartPlaylistEditor(playlist: playlist),
  );
}

class SmartPlaylistEditor extends ConsumerStatefulWidget {
  const SmartPlaylistEditor({super.key, this.playlist});

  /// 为空表示新建；非空表示编辑该智能列表。
  final PlaylistDto? playlist;

  @override
  ConsumerState<SmartPlaylistEditor> createState() =>
      _SmartPlaylistEditorState();
}

class _SmartPlaylistEditorState extends ConsumerState<SmartPlaylistEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TagSelectionScope _tagSelectionScope;

  late SmartPlaylistDraft _draft;
  final Map<int, ActorListItemDto> _actorById = <int, ActorListItemDto>{};

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.playlist != null;

  @override
  void initState() {
    super.initState();
    final playlist = widget.playlist;
    final smart = playlist?.smartFilter;
    _nameController = TextEditingController(text: playlist?.name ?? '');
    _descriptionController = TextEditingController(
      text: playlist?.description ?? '',
    );
    _draft = SmartPlaylistDraft.fromFilter(smart);
    _tagSelectionScope = TagSelectionScope.custom(
      instanceKey: 'smart-playlist-editor:${playlist?.id ?? 'new'}',
      initialSelectedTagIds: smart?.tagIds ?? const <int>[],
      initialMatchMode: TagMatchModeX.fromApiValue(smart?.tagMatch ?? 'or'),
    );
    if (_draft.actorIds.isNotEmpty) {
      unawaited(_loadActors(_draft.actorIds));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadActors(List<int> actorIds) async {
    try {
      final api = ref.read(actorsApiProvider);
      final details = await Future.wait(
        actorIds.map((actorId) => api.getActorDetail(actorId: actorId)),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        for (final detail in details) {
          _actorById[detail.summary.id] = detail.summary;
        }
      });
    } catch (_) {
      // 女优信息加载失败时保留 actor_ids，保存不会丢条件。
    }
  }

  Future<void> _pickActors() async {
    final picked = await showMovieActorPickerSheet(
      context,
      actorsApi: ref.read(actorsApiProvider),
      existingActorIds: _draft.actorIds.toSet(),
    );
    if (!mounted || picked == null || picked.isEmpty) {
      return;
    }
    final nextIds = <int>[..._draft.actorIds];
    setState(() {
      for (final actor in picked) {
        if (!nextIds.contains(actor.id)) {
          nextIds.add(actor.id);
        }
        _actorById[actor.id] = actor;
      }
      _draft = _draft.copyWith(actorIds: nextIds);
    });
  }

  void _removeActor(int actorId) {
    setState(() {
      _actorById.remove(actorId);
      _draft = _draft.copyWith(
        actorIds: _draft.actorIds
            .where((value) => value != actorId)
            .toList(growable: false),
      );
    });
  }

  void _toggleStatus(MovieStatusFilter status) {
    final next = Set<MovieStatusFilter>.of(_draft.statuses);
    if (!next.remove(status)) {
      next.add(status);
    }
    var draft = _draft.copyWith(statuses: next);
    if (!next.contains(MovieStatusFilter.playable)) {
      // 分辨率只在「可播放」下生效，取消可播放时同步清空，避免留下隐形条件。
      draft = draft.copyWith(resolutions: const <PlaylistResolutionFilter>{});
    }
    setState(() => _draft = draft);
  }

  void _toggleWatchStatus(MovieWatchStatusFilter status) {
    final next = Set<MovieWatchStatusFilter>.of(_draft.watchStatuses);
    if (!next.remove(status)) {
      next.add(status);
    }
    setState(() => _draft = _draft.copyWith(watchStatuses: next));
  }

  void _toggleYear(int year) {
    final next = Set<int>.of(_draft.years);
    if (!next.remove(year)) {
      next.add(year);
    }
    setState(() => _draft = _draft.copyWith(years: next));
  }

  void _toggleResolution(PlaylistResolutionFilter resolution) {
    final next = Set<PlaylistResolutionFilter>.of(_draft.resolutions);
    if (!next.remove(resolution)) {
      next.add(resolution);
    }
    setState(() => _draft = _draft.copyWith(resolutions: next));
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final tagSelection = ref.read(tagSelectionProvider(_tagSelectionScope));
    final statsEnabled = ref.read(statsFeaturesEnabledProvider);
    // 统计能力关闭时编辑器隐藏了热度条件；保存时同步清理，避免写回看不见的条件。
    final draft = statsEnabled
        ? _draft
        : _draft.copyWith(
            sortField: visiblePlaylistSortField(
              _draft.sortField,
              statsEnabled: false,
            ),
            interaction: MovieInteractionFilter.initial,
          );
    final filter = draft.toFilterJson(
      tagIds: tagSelection.selectedTagIds,
      tagMatch: tagSelection.matchMode,
    );
    final api = ref.read(playlistsApiProvider);
    try {
      final result = _isEditing
          ? await api.updatePlaylist(
              playlistId: widget.playlist!.id,
              payload: UpdatePlaylistPayload(
                name: _nameController.text.trim(),
                description: _descriptionController.text.trim(),
                filter: filter,
              ),
            )
          : await api.createPlaylist(
              name: _nameController.text,
              description: _descriptionController.text,
              kind: PlaylistKind.smart,
              smartFilter: filter,
            );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        _isSubmitting = false;
        _errorMessage = apiErrorMessage(
          error,
          fallback: l10n.smartPlaylistCreateFailed,
          l10n: l10n,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppBottomFormSheet(
      key: const Key('smart-playlist-editor-form'),
      formKey: _formKey,
      title: _isEditing
          ? l10n.smartPlaylistEditTitle
          : l10n.smartPlaylistCreateTitle,
      body: _buildBody(context, l10n),
      submitKey: const Key('smart-playlist-editor-submit'),
      submitLabel: _isEditing ? l10n.commonSave : l10n.playlistCreateAction,
      isSubmitting: _isSubmitting,
      onSubmit: _submit,
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final spacing = context.appSpacing;
    final statsEnabled = ref.watch(statsFeaturesEnabledProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) ...[
          Text(
            _errorMessage!,
            key: const Key('smart-playlist-editor-error'),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.error,
            ),
          ),
          SizedBox(height: spacing.md),
        ],
        _buildBasicsCard(context, l10n),
        SizedBox(height: spacing.lg),
        _buildActorsCard(context, l10n),
        SizedBox(height: spacing.lg),
        _buildStatusCard(context, l10n),
        SizedBox(height: spacing.lg),
        _buildWatchStatusCard(context, l10n),
        SizedBox(height: spacing.lg),
        _buildYearsCard(context, l10n),
        SizedBox(height: spacing.lg),
        _buildResolutionsCard(context, l10n),
        SizedBox(height: spacing.lg),
        AppContentCard(
          key: const Key('smart-playlist-tags-card'),
          child: TagFilterSection(
            scope: _tagSelectionScope,
            selectionStyle: AppFilterChipSelectionStyle.accent,
          ),
        ),
        SizedBox(height: spacing.lg),
        AppContentCard(
          key: const Key('smart-playlist-media-tags-card'),
          child: MediaTagFilterSection(
            selectionStyle: AppFilterChipSelectionStyle.accent,
            mediaTagIds: _draft.mediaTagIds,
            mediaTagMatch: _draft.mediaTagMatch,
            onChanged: (ids, matchMode) => setState(
              () => _draft = _draft.copyWith(
                mediaTagIds: ids,
                mediaTagMatch: matchMode,
              ),
            ),
          ),
        ),
        SizedBox(height: spacing.lg),
        _buildRangesCard(context, statsEnabled: statsEnabled),
        SizedBox(height: spacing.lg),
        _buildTypeCard(context, l10n),
        SizedBox(height: spacing.lg),
        _buildSortCard(context, l10n, statsEnabled: statsEnabled),
      ],
    );
  }

  Widget _buildBasicsCard(BuildContext context, AppLocalizations l10n) {
    final spacing = context.appSpacing;
    return AppContentCard(
      key: const Key('smart-playlist-basics-card'),
      title: l10n.smartPlaylistBasicInfoTitle,
      headerBottomSpacing: spacing.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            fieldKey: const Key('smart-playlist-name-field'),
            controller: _nameController,
            label: l10n.smartPlaylistNameLabel,
            hintText: l10n.smartPlaylistNameHint,
            enabled: !_isSubmitting,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) => value == null || value.trim().isEmpty
                ? l10n.playlistNameRequired
                : null,
          ),
          SizedBox(height: spacing.sm),
          AppTextField(
            fieldKey: const Key('smart-playlist-description-field'),
            controller: _descriptionController,
            hintText: l10n.playlistDescriptionHint,
            enabled: !_isSubmitting,
            maxLines: 2,
            minLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildActorsCard(BuildContext context, AppLocalizations l10n) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    return AppContentCard(
      key: const Key('smart-playlist-actors-card'),
      title: l10n.smartPlaylistActorsTitle,
      headerTrailing: _buildMatchToggle(
        mode: _draft.actorMatch,
        selectedCount: _draft.actorIds.length,
        buttonKeyPrefix: 'smart-playlist-actor-match',
        onChanged: (value) =>
            setState(() => _draft = _draft.copyWith(actorMatch: value)),
      ),
      headerBottomSpacing: spacing.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_draft.actorIds.isNotEmpty)
            Wrap(
              spacing: spacing.xs,
              runSpacing: spacing.xs,
              children: <Widget>[
                for (final actorId in _draft.actorIds)
                  if (_actorById[actorId] case final actor?)
                    AppInteractiveSurface(
                      key: Key('smart-playlist-actor-chip-$actorId'),
                      onTap: _isSubmitting ? null : () => _removeActor(actorId),
                      focusRingRadius: context.appRadius.pillBorder,
                      child: AppPill(
                        label: actor.displayName,
                        leading: ActorAvatar(
                          imageUrl: actor.profileImage?.origin,
                          size: tokens.iconSizeSm,
                        ),
                        trailing: Icon(
                          Icons.close_rounded,
                          size: tokens.iconSizeXs,
                        ),
                      ),
                    ),
              ],
            ),
          if (_draft.actorIds.isNotEmpty) SizedBox(height: spacing.sm),
          AppTextButton(
            key: const Key('smart-playlist-add-actors'),
            label: l10n.smartPlaylistAddActorsAction,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            emphasis: AppTextButtonEmphasis.accent,
            size: AppTextButtonSize.xSmall,
            onPressed: _isSubmitting ? null : _pickActors,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, AppLocalizations l10n) {
    return AppContentCard(
      key: const Key('smart-playlist-status-card'),
      title: l10n.widgetMovieFilterStatusTitle,
      headerTrailing: _buildMatchToggle(
        mode: _draft.statusMatch,
        selectedCount: _draft.statuses.length,
        buttonKeyPrefix: 'smart-playlist-status-match',
        onChanged: (value) =>
            setState(() => _draft = _draft.copyWith(statusMatch: value)),
      ),
      headerBottomSpacing: context.appSpacing.md,
      child: _FilterChipGroup<MovieStatusFilter>(
        keyPrefix: 'smart-playlist-status',
        options: const <MovieStatusFilter>[
          MovieStatusFilter.subscribed,
          MovieStatusFilter.unsubscribed,
          MovieStatusFilter.playable,
        ],
        selected: _draft.statuses,
        labelBuilder: (value) => value.labelWith(l10n),
        optionKeyBuilder: (value) => value.name,
        onToggle: _toggleStatus,
        onClear: () =>
            setState(() => _draft = _draft.copyWith(statuses: const {})),
      ),
    );
  }

  Widget _buildWatchStatusCard(BuildContext context, AppLocalizations l10n) {
    return AppContentCard(
      key: const Key('smart-playlist-watch-status-card'),
      title: l10n.movieFilterWatchStatusTitle,
      headerTrailing: _buildMatchToggle(
        mode: _draft.watchMatch,
        selectedCount: _draft.watchStatuses.length,
        buttonKeyPrefix: 'smart-playlist-watch-match',
        onChanged: (value) =>
            setState(() => _draft = _draft.copyWith(watchMatch: value)),
      ),
      headerBottomSpacing: context.appSpacing.md,
      child: _FilterChipGroup<MovieWatchStatusFilter>(
        keyPrefix: 'smart-playlist-watch-status',
        options: const <MovieWatchStatusFilter>[
          MovieWatchStatusFilter.unwatched,
          MovieWatchStatusFilter.watching,
          MovieWatchStatusFilter.watched,
        ],
        selected: _draft.watchStatuses,
        labelBuilder: (value) => value.labelWith(l10n),
        optionKeyBuilder: (value) => value.name,
        onToggle: _toggleWatchStatus,
        onClear: () =>
            setState(() => _draft = _draft.copyWith(watchStatuses: const {})),
      ),
    );
  }

  Widget _buildYearsCard(BuildContext context, AppLocalizations l10n) {
    return AppContentCard(
      key: const Key('smart-playlist-years-card'),
      title: l10n.widgetMovieFilterYearTitle,
      headerBottomSpacing: context.appSpacing.md,
      child: _FilterChipGroup<int>(
        keyPrefix: 'smart-playlist-year',
        options: <int>[
          for (final option in buildDefaultMovieFilterYearOptions())
            option.year,
        ],
        selected: _draft.years,
        labelBuilder: (value) => '$value',
        onToggle: _toggleYear,
        onClear: () =>
            setState(() => _draft = _draft.copyWith(years: const {})),
      ),
    );
  }

  Widget _buildResolutionsCard(BuildContext context, AppLocalizations l10n) {
    final spacing = context.appSpacing;
    final enabled = _draft.isResolutionEnabled;
    return AppContentCard(
      key: const Key('smart-playlist-resolutions-card'),
      title: l10n.widgetMovieFilterResolutionTitle,
      headerBottomSpacing: spacing.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterChipGroup<PlaylistResolutionFilter>(
            keyPrefix: 'smart-playlist-resolution',
            options: PlaylistResolutionFilter.values,
            selected: _draft.resolutions,
            labelBuilder: (value) => value.label,
            optionKeyBuilder: (value) => value.name,
            enabled: enabled,
            onToggle: _toggleResolution,
            onClear: () => setState(
              () => _draft = _draft.copyWith(
                resolutions: const <PlaylistResolutionFilter>{},
              ),
            ),
          ),
          if (!enabled) ...[
            SizedBox(height: spacing.xs),
            Text(
              l10n.smartPlaylistResolutionRequiresPlayable,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRangesCard(BuildContext context, {required bool statsEnabled}) {
    final spacing = context.appSpacing;
    return AppContentCard(
      key: const Key('smart-playlist-ranges-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (statsEnabled) ...[
            MovieInteractionRangeFilterSectionGroup(
              filter: _draft.interaction,
              showHeader: false,
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(interaction: value)),
            ),
            SizedBox(height: spacing.lg),
          ],
          MovieActorAgeRangeFilterSection(
            actorAgeMin: _draft.actorAgeMin,
            actorAgeMax: _draft.actorAgeMax,
            onChanged: (range) => setState(
              () => _draft = _draft.copyWith(
                actorAgeMin: range.$1,
                actorAgeMax: range.$2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard(BuildContext context, AppLocalizations l10n) {
    final spacing = context.appSpacing;
    return AppContentCard(
      key: const Key('smart-playlist-type-card'),
      title: l10n.smartPlaylistTypeSectionTitle,
      headerBottomSpacing: spacing.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RowLabel(label: l10n.widgetMovieFilterCollectionTypeTitle),
          SizedBox(height: spacing.xs),
          Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: [
              AppFilterChip(
                key: const Key('smart-playlist-collection-all'),
                label: l10n.sharedInteractionUnlimited,
                selected:
                    _draft.collectionType == MovieCollectionTypeFilter.all,
                selectionStyle: AppFilterChipSelectionStyle.accent,
                onPressed: () => setState(
                  () => _draft = _draft.copyWith(
                    collectionType: MovieCollectionTypeFilter.all,
                  ),
                ),
              ),
              AppFilterChip(
                key: const Key('smart-playlist-collection-single'),
                label: MovieCollectionTypeFilter.single.labelWith(l10n),
                selected:
                    _draft.collectionType == MovieCollectionTypeFilter.single,
                selectionStyle: AppFilterChipSelectionStyle.accent,
                onPressed: () => setState(
                  () => _draft = _draft.copyWith(
                    collectionType: MovieCollectionTypeFilter.single,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.md),
          _RowLabel(label: l10n.widgetMovieFilterNumberSourceTitle),
          SizedBox(height: spacing.xs),
          Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: [
              for (final value in MovieNumberSourceFilter.values)
                AppFilterChip(
                  key: Key('smart-playlist-number-source-${value.name}'),
                  label: value == MovieNumberSourceFilter.all
                      ? l10n.sharedInteractionUnlimited
                      : value.labelWith(l10n),
                  selected: _draft.numberSource == value,
                  selectionStyle: AppFilterChipSelectionStyle.accent,
                  onPressed: () => setState(
                    () => _draft = _draft.copyWith(numberSource: value),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortCard(
    BuildContext context,
    AppLocalizations l10n, {
    required bool statsEnabled,
  }) {
    final spacing = context.appSpacing;
    final sortFields = visiblePlaylistSortFields(statsEnabled: statsEnabled);
    return AppContentCard(
      key: const Key('smart-playlist-sort-card'),
      title: l10n.smartPlaylistSortTitle,
      headerBottomSpacing: spacing.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RowLabel(label: l10n.smartPlaylistSortFieldTitle),
          SizedBox(height: spacing.xs),
          Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: [
              for (final field in sortFields)
                AppFilterChip(
                  key: Key('smart-playlist-sort-field-${field.name}'),
                  label: field.label(l10n),
                  selected: _draft.sortField == field,
                  selectionStyle: AppFilterChipSelectionStyle.accent,
                  onPressed: () => setState(
                    () => _draft = _draft.copyWith(sortField: field),
                  ),
                ),
            ],
          ),
          SizedBox(height: spacing.md),
          _RowLabel(label: l10n.smartPlaylistSortDirectionTitle),
          SizedBox(height: spacing.xs),
          Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: [
              for (final direction in SortDirection.values)
                AppFilterChip(
                  key: Key('smart-playlist-sort-direction-${direction.name}'),
                  label: direction.label(l10n),
                  selected: _draft.sortDirection == direction,
                  selectionStyle: AppFilterChipSelectionStyle.accent,
                  onPressed: () => setState(
                    () => _draft = _draft.copyWith(sortDirection: direction),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildMatchToggle({
    required TagMatchMode mode,
    required int selectedCount,
    required String buttonKeyPrefix,
    required ValueChanged<TagMatchMode> onChanged,
  }) {
    if (selectedCount < 2) {
      return null;
    }
    return AppTagMatchModeToggle(
      matchMode: mode,
      onChanged: onChanged,
      buttonKeyPrefix: buttonKeyPrefix,
    );
  }
}

class _FilterChipGroup<T> extends StatelessWidget {
  const _FilterChipGroup({
    required this.keyPrefix,
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onToggle,
    required this.onClear,
    this.optionKeyBuilder,
    this.enabled = true,
  });

  final String keyPrefix;
  final List<T> options;
  final Set<T> selected;
  final String Function(T value) labelBuilder;
  final String Function(T value)? optionKeyBuilder;
  final ValueChanged<T> onToggle;
  final VoidCallback onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: spacing.xs,
      runSpacing: spacing.xs,
      children: [
        AppFilterChip(
          key: Key('$keyPrefix-all'),
          label: l10n.sharedInteractionUnlimited,
          selected: selected.isEmpty,
          selectionStyle: AppFilterChipSelectionStyle.accent,
          enabled: enabled,
          onPressed: enabled ? onClear : null,
        ),
        for (final option in options)
          AppFilterChip(
            key: Key('$keyPrefix-${optionKeyBuilder?.call(option) ?? option}'),
            label: labelBuilder(option),
            selected: selected.contains(option),
            selectionStyle: AppFilterChipSelectionStyle.accent,
            enabled: enabled,
            onPressed: enabled ? () => onToggle(option) : null,
          ),
      ],
    );
  }
}

class _RowLabel extends StatelessWidget {
  const _RowLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.medium,
        tone: AppTextTone.secondary,
      ),
    );
  }
}
