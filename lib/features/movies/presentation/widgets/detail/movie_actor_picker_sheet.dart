import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_picker_layout.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_avatar.dart';

/// 影片演员表的添加弹层：搜索女优库、多选，或原地新建本地女优。
///
/// 返回值只包含用户选中的演员；真正写入影片关联由调用方统一处理。
Future<List<ActorListItemDto>?> showMovieActorPickerSheet(
  BuildContext context, {
  required ActorsApi actorsApi,
  required Set<int> existingActorIds,
}) {
  return showAppAdaptiveModal<List<ActorListItemDto>>(
    context: context,
    modalKey: const Key('movie-actor-picker'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    builder: (_) => MovieActorPickerSheet(
      actorsApi: actorsApi,
      existingActorIds: existingActorIds,
    ),
  );
}

enum _PickerMode { pick, create }

/// 搜索态与新建态共用固定主体高度，避免搜索状态切换时弹窗上下跳动。
const double _pickerBodyHeight = 380;

class MovieActorPickerSheet extends StatefulWidget {
  const MovieActorPickerSheet({
    super.key,
    required this.actorsApi,
    required this.existingActorIds,
  });

  final ActorsApi actorsApi;
  final Set<int> existingActorIds;

  @override
  State<MovieActorPickerSheet> createState() => _MovieActorPickerSheetState();
}

class _MovieActorPickerSheetState extends State<MovieActorPickerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _createNameController = TextEditingController();
  final _createAliasController = TextEditingController();
  final Map<int, ActorListItemDto> _selected = <int, ActorListItemDto>{};

  _PickerMode _mode = _PickerMode.pick;
  Timer? _debounce;
  int _searchRequestId = 0;
  List<ActorListItemDto> _candidates = const <ActorListItemDto>[];
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isCreating = false;
  String? _searchErrorMessage;
  String? _createErrorMessage;

  String get _query => _searchController.text.trim();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _createNameController.dispose();
    _createAliasController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _searchRequestId++;
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _candidates = const <ActorListItemDto>[];
        _hasSearched = false;
        _isSearching = false;
        _searchErrorMessage = null;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_search(query)),
    );
  }

  Future<void> _search(String query) async {
    final requestId = ++_searchRequestId;
    setState(() {
      _isSearching = true;
      _searchErrorMessage = null;
    });
    try {
      final page = await widget.actorsApi.getActors(
        query: query,
        pageSize: 20,
        subscriptionStatus: ActorSubscriptionStatus.all,
        gender: ActorGender.all,
      );
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _candidates = page.items;
        _hasSearched = true;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted || requestId != _searchRequestId) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _hasSearched = true;
        _isSearching = false;
        _searchErrorMessage = apiErrorMessage(
          error,
          fallback: l10n.movieWidgetActorSearchFailed,
          l10n: l10n,
        );
      });
    }
  }

  void _toggleCandidate(ActorListItemDto candidate, bool? selected) {
    setState(() {
      if (selected == true) {
        _selected[candidate.id] = candidate;
      } else {
        _selected.remove(candidate.id);
      }
    });
  }

  void _enterCreate([String? query]) {
    final seed = (query ?? _query).trim();
    _createNameController.text = seed;
    _createAliasController.clear();
    setState(() {
      _mode = _PickerMode.create;
      _createErrorMessage = null;
    });
  }

  void _backToPick() {
    setState(() {
      _mode = _PickerMode.pick;
      _createErrorMessage = null;
    });
  }

  void _submitPick() {
    if (_selected.isEmpty) return;
    Navigator.of(
      context,
    ).pop(List<ActorListItemDto>.unmodifiable(_selected.values));
  }

  Future<void> _submitCreate() async {
    if (_isCreating) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isCreating = true;
      _createErrorMessage = null;
    });
    try {
      final created = await widget.actorsApi.createLocalActor(
        name: _createNameController.text,
        aliasName: _createAliasController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(<ActorListItemDto>[created.summary]);
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _isCreating = false;
        _createErrorMessage = apiErrorMessage(
          error,
          fallback: l10n.movieWidgetLocalActorCreateFailed,
          l10n: l10n,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreate = _mode == _PickerMode.create;
    final l10n = AppLocalizations.of(context);
    return AppBottomFormSheet(
      key: const Key('movie-actor-picker-form'),
      formKey: _formKey,
      title: isCreate
          ? l10n.movieWidgetCreateLocalActorTitle
          : l10n.movieWidgetAddActorTitle,
      subtitle: isCreate
          ? l10n.movieWidgetCreateLocalActorSubtitle
          : l10n.movieWidgetActorPickerSubtitle,
      submitKey: Key(
        isCreate ? 'movie-actor-create-confirm' : 'movie-actor-picker-confirm',
      ),
      submitLabel: isCreate
          ? l10n.movieWidgetCreateAndAdd
          : (_selected.isEmpty
                ? l10n.movieWidgetAddActorTitle
                : l10n.movieWidgetAddActorsCount(_selected.length)),
      isSubmitting: _isCreating,
      submitDisabled: !isCreate && _selected.isEmpty,
      onSubmit: () {
        if (isCreate) {
          unawaited(_submitCreate());
        } else {
          _submitPick();
        }
      },
      body: isCreate ? _buildCreateBody(context) : _buildPickBody(context),
    );
  }

  Widget _buildPickBody(BuildContext context) {
    final spacing = context.appSpacing;
    final query = _query;
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: _pickerBodyHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            fieldKey: const Key('movie-actor-picker-search-field'),
            controller: _searchController,
            label: l10n.movieWidgetSearchActorLabel,
            hintText: l10n.movieWidgetActorSearchHint,
            textInputAction: TextInputAction.search,
            onChanged: _onQueryChanged,
            onFieldSubmitted: (value) {
              _debounce?.cancel();
              final normalized = value.trim();
              if (normalized.isNotEmpty) {
                unawaited(_search(normalized));
              }
            },
          ),
          SizedBox(height: spacing.md),
          Expanded(child: _buildResults(context, query)),
          if (_selected.isNotEmpty) ...[
            SizedBox(height: spacing.sm),
            Text(
              l10n.movieWidgetSelectedActorsSummary(
                _selected.length,
                _selected.values
                    .map((item) => item.displayName)
                    .join(l10n.movieWidgetActorNameSeparator),
              ),
              key: const Key('movie-actor-picker-selection-summary'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.secondary,
              ),
            ),
          ],
          if (_searchErrorMessage != null) ...[
            SizedBox(height: spacing.sm),
            Text(
              _searchErrorMessage!,
              key: const Key('movie-actor-picker-search-error'),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, String query) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchErrorMessage != null) {
      return const SizedBox.shrink();
    }
    if (!_hasSearched) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          l10n.movieWidgetActorSearchPrompt,
          key: const Key('movie-actor-picker-hint'),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
      );
    }
    if (_candidates.isEmpty) {
      return Column(
        key: const Key('movie-actor-picker-empty'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.movieWidgetActorNotFound,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
          if (query.isNotEmpty) ...[
            SizedBox(height: spacing.sm),
            AppButton(
              key: const Key('movie-actor-picker-create-entry'),
              label: l10n.movieWidgetCreateLocalActorWithName(query),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              size: AppButtonSize.small,
              onPressed: () => _enterCreate(query),
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: AppPickerIosSection(
              dividerIndent: 68,
              children: [
                for (final candidate in _candidates)
                  _buildCandidateTile(context, candidate),
              ],
            ),
          ),
        ),
        if (query.isNotEmpty) ...[
          SizedBox(height: spacing.xs),
          AppTextButton(
            key: const Key('movie-actor-picker-create-entry'),
            label: l10n.movieWidgetCreateLocalActorEntry,
            size: AppTextButtonSize.xSmall,
            emphasis: AppTextButtonEmphasis.accent,
            onPressed: () => _enterCreate(query),
          ),
        ],
      ],
    );
  }

  Widget _buildCandidateTile(BuildContext context, ActorListItemDto candidate) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    final l10n = AppLocalizations.of(context);
    final isExisting = widget.existingActorIds.contains(candidate.id);
    final isSelected = _selected.containsKey(candidate.id);
    return AppPickerIosRow(
      optionKey: Key('movie-actor-picker-candidate-${candidate.id}'),
      selected: isExisting || isSelected,
      showCheckmark: true,
      enabled: !isExisting,
      onTap: () => _toggleCandidate(candidate, !isSelected),
      title: candidate.displayName,
      leading: ActorAvatar(
        imageUrl: candidate.profileImage?.origin,
        size: tokens.iconSize2xl,
        placeholderKey: Key(
          'movie-actor-picker-avatar-placeholder-${candidate.id}',
        ),
      ),
      subtitleWidget: Row(
        children: [
          Flexible(
            child: Text(
              candidate.isLocal
                  ? l10n.movieWidgetLocalActorBadge
                  : candidate.javdbId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.muted,
              ),
            ),
          ),
          if (isExisting) ...[
            SizedBox(width: spacing.xs),
            AppBadge(
              label: l10n.movieWidgetActorAlreadyInCast,
              size: AppBadgeSize.compact,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreateBody(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: _pickerBodyHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppTextButton(
              key: const Key('movie-actor-create-back'),
              label: l10n.movieWidgetBackToSelection,
              icon: Icon(
                Icons.arrow_back_rounded,
                size: context.appComponentTokens.iconSizeXs,
              ),
              size: AppTextButtonSize.xSmall,
              onPressed: _isCreating ? null : _backToPick,
            ),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('movie-actor-create-name-field'),
            controller: _createNameController,
            label: l10n.movieWidgetActorNameLabel,
            hintText: l10n.movieWidgetActorNameRequired,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              final name = value?.trim() ?? '';
              if (name.isEmpty) return l10n.movieWidgetActorNameRequired;
              if (name.length > 255) return l10n.movieWidgetActorNameTooLong;
              return null;
            },
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('movie-actor-create-alias-field'),
            controller: _createAliasController,
            label: l10n.movieWidgetActorAliasLabel,
            hintText: l10n.movieWidgetActorAliasHint,
            helperText: l10n.movieWidgetActorAliasHelper,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              final alias = value?.trim() ?? '';
              if (alias.length > 1024) return l10n.movieWidgetActorAliasTooLong;
              return null;
            },
          ),
          if (_createErrorMessage != null) ...[
            SizedBox(height: spacing.sm),
            Text(
              _createErrorMessage!,
              key: const Key('movie-actor-create-error'),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
