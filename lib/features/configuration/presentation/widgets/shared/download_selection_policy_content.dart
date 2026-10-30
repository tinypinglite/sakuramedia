import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_selection_policy_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/indexer_settings_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_selection_policy_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_selection_policy_state.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/indexer_settings_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/download_selection_indexer_picker.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/download_selection_keyword_group_editor.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_switch.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_pill.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';
import 'package:sakuramedia/widgets/domain/downloads/download_candidate_selection_summary.dart';

const int _bytesPerGiB = 1024 * 1024 * 1024;

class DownloadSelectionPolicyContent extends ConsumerStatefulWidget {
  const DownloadSelectionPolicyContent({
    super.key,
    required this.mobile,
    this.onDirtyChanged,
  });

  final bool mobile;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  ConsumerState<DownloadSelectionPolicyContent> createState() =>
      _DownloadSelectionPolicyContentState();
}

class _DownloadSelectionPolicyContentState
    extends ConsumerState<DownloadSelectionPolicyContent> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _minSizeController = TextEditingController();
  final TextEditingController _maxSizeController = TextEditingController();
  final TextEditingController _minSeedersController = TextEditingController();
  final TextEditingController _maxAgeController = TextEditingController();
  final TextEditingController _previewMovieController = TextEditingController();

  int _initializedVersion = -1;
  bool _localTextEdits = false;
  bool _showRuleErrors = false;
  bool _lastReportedDirty = false;
  String? _previewValidationMessage;
  String? _previewNormalizedMovieNumber;
  bool _isParsingPreviewMovieNumber = false;
  int _previewMovieInputVersion = 0;

  @override
  void dispose() {
    _previewMovieInputVersion++;
    _minSizeController.dispose();
    _maxSizeController.dispose();
    _minSeedersController.dispose();
    _maxAgeController.dispose();
    _previewMovieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final policyAsync = ref.watch(downloadSelectionPolicyProvider);
    final policyState = policyAsync.value;
    if (policyState != null) {
      _syncControllers(policyState);
    }
    final dirty =
        policyState != null && (policyState.isDirty || _localTextEdits);
    _reportDirty(dirty);

    if (policyAsync.isLoading && policyState == null) {
      return _buildBodyShell(
        const Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (policyAsync.hasError && policyState == null) {
      final l10n = AppLocalizations.of(context);
      return _buildBodyShell(
        AppSectionError(
          title: l10n.downloadSelectionLoadFailed,
          message: apiErrorMessage(
            policyAsync.error!,
            fallback: l10n.downloadSelectionLoadFailedFallback,
            l10n: l10n,
          ),
          onRetry: () =>
              ref.read(downloadSelectionPolicyProvider.notifier).reload(),
        ),
      );
    }
    if (policyState == null) return const SizedBox.shrink();

    final indexerSettingsAsync = ref.watch(indexerSettingsProvider);
    final indexerSettings = indexerSettingsAsync.value;
    final indexers =
        indexerSettings?.saved.indexers ?? const <IndexerEntryDto>[];
    final indexerCatalogAvailable =
        indexerSettingsAsync.hasValue &&
        !indexerSettingsAsync.isLoading &&
        !indexerSettingsAsync.hasError;
    final colors = context.appColors;
    final spacing = context.appSpacing;
    return ColoredBox(
      key: const Key('download-selection-policy-content'),
      color: widget.mobile ? colors.surfaceCard : Colors.transparent,
      child: Column(
        children: [
          if (!widget.mobile) _buildDesktopHeader(policyState, dirty),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('download-selection-policy-scroll'),
              padding: EdgeInsets.fromLTRB(
                widget.mobile ? spacing.md : 0,
                widget.mobile ? spacing.md : 0,
                widget.mobile ? spacing.md : spacing.lg,
                spacing.xxl,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppNoticeCard(
                      leadingIcon: Icons.filter_alt_outlined,
                      title: AppLocalizations.of(
                        context,
                      ).downloadSelectionOverviewTitle,
                      description: AppLocalizations.of(
                        context,
                      ).downloadSelectionOverviewDescription,
                    ),
                    if (policyState.hasVersionConflict) ...[
                      SizedBox(height: spacing.md),
                      _VersionConflictBanner(
                        onReload: () => unawaited(_reloadAfterConflict()),
                      ),
                    ],
                    SizedBox(height: spacing.lg),
                    _buildScopeSection(
                      policyState,
                      indexers,
                      indexerCatalogAvailable: indexerCatalogAvailable,
                    ),
                    SizedBox(height: spacing.lg),
                    _buildKeywordSection(policyState),
                    SizedBox(height: spacing.lg),
                    _buildRankingSection(
                      policyState,
                      indexers,
                      indexerCatalogAvailable: indexerCatalogAvailable,
                    ),
                    SizedBox(height: spacing.lg),
                    _buildPreviewSection(policyState),
                  ],
                ),
              ),
            ),
          ),
          if (widget.mobile) _buildSaveFooter(policyState, dirty),
        ],
      ),
    );
  }

  void _syncControllers(DownloadSelectionPolicyState state) {
    if (_initializedVersion == state.saved.version) return;
    _initializedVersion = state.saved.version;
    _localTextEdits = false;
    _minSizeController.text = _formatGiB(state.draft.minSizeBytes);
    _maxSizeController.text = state.draft.maxSizeBytes == null
        ? ''
        : _formatGiB(state.draft.maxSizeBytes!);
    _minSeedersController.text = '${state.draft.minSeeders}';
    _maxAgeController.text = state.draft.maxAgeDays?.toString() ?? '';
    final previewMovieNumber = state.previewMovieNumber;
    if (previewMovieNumber != null && previewMovieNumber.isNotEmpty) {
      _previewMovieController.text = previewMovieNumber;
    }
  }

  void _reportDirty(bool dirty) {
    if (dirty == _lastReportedDirty) return;
    _lastReportedDirty = dirty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDirtyChanged?.call(dirty);
    });
  }

  Widget _buildScopeSection(
    DownloadSelectionPolicyState state,
    List<IndexerEntryDto> indexers, {
    required bool indexerCatalogAvailable,
  }) {
    final l10n = AppLocalizations.of(context);
    final rules = state.draft;
    final availableNames = indexers
        .map((item) => item.name)
        .toList(growable: false);
    final unknownNames = indexerCatalogAvailable
        ? rules.indexerNames
              .where(
                (name) => !availableNames.any(
                  (item) => item.toLowerCase() == name.toLowerCase(),
                ),
              )
              .toList(growable: false)
        : const <String>[];
    return AppSettingsGroup(
      key: const Key('download-selection-scope-section'),
      header: l10n.downloadSelectionScopeSection,
      children: [
        _sectionPadding(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLabel(l10n.downloadSelectionIndexerKindsLabel),
              SizedBox(height: context.appSpacing.sm),
              Wrap(
                spacing: context.appSpacing.sm,
                runSpacing: context.appSpacing.xs,
                children: [
                  AppPillButton(
                    key: const Key('download-selection-indexer-kind-all'),
                    label: l10n.downloadSelectionAny,
                    isSelected: rules.indexerKinds.isEmpty,
                    tone: rules.indexerKinds.isEmpty
                        ? AppPillTone.primary
                        : AppPillTone.neutral,
                    onTap: () => _updateRules(
                      rules.copyWith(indexerKinds: const <String>[]),
                    ),
                  ),
                  for (final entry in const <(String, String)>[
                    ('pt', 'PT'),
                    ('bt', 'BT'),
                  ])
                    AppPillButton(
                      key: Key('download-selection-indexer-kind-${entry.$1}'),
                      label: entry.$2,
                      isSelected: rules.indexerKinds.contains(entry.$1),
                      tone: rules.indexerKinds.contains(entry.$1)
                          ? AppPillTone.primary
                          : AppPillTone.neutral,
                      onTap: () {
                        final next = List<String>.from(rules.indexerKinds);
                        if (!next.remove(entry.$1)) next.add(entry.$1);
                        _updateRules(rules.copyWith(indexerKinds: next));
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        _sectionPadding(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _FieldLabel(l10n.downloadSelectionIndexerNamesLabel),
                  ),
                  _TextAction(
                    key: const Key('download-selection-indexer-names-edit'),
                    label: l10n.commonEdit,
                    onTap: () => unawaited(
                      _editIndexerNames(
                        rules: rules,
                        availableNames: availableNames,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.appSpacing.xs),
              _buildStringPills(
                rules.indexerNames,
                emptyLabel: l10n.downloadSelectionAllIndexers,
                warningNames: unknownNames.toSet(),
              ),
              if (unknownNames.isNotEmpty) ...[
                SizedBox(height: context.appSpacing.sm),
                _RuleWarning(
                  l10n.downloadSelectionIndexerUnavailableWarning(
                    unknownNames.join(', '),
                  ),
                ),
              ],
            ],
          ),
        ),
        _sectionPadding(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fields = <Widget>[
                AppTextField(
                  fieldKey: const Key('download-selection-min-size'),
                  controller: _minSizeController,
                  label: l10n.downloadSelectionMinSizeLabel,
                  suffix: _unitSuffix(
                    context,
                    key: const Key('download-selection-min-size-unit'),
                    unit: 'GiB',
                  ),
                  tightSuffix: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateMinSize,
                  onChanged: (_) => _handleNumericTextChanged(),
                ),
                AppTextField(
                  fieldKey: const Key('download-selection-max-size'),
                  controller: _maxSizeController,
                  label: l10n.downloadSelectionMaxSizeLabel,
                  helperText: l10n.downloadSelectionNoLimitHint,
                  suffix: _unitSuffix(
                    context,
                    key: const Key('download-selection-max-size-unit'),
                    unit: 'GiB',
                  ),
                  tightSuffix: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateMaxSize,
                  onChanged: (_) => _handleNumericTextChanged(),
                ),
              ];
              return _AdaptiveFieldRow(
                constraints: constraints,
                children: fields,
              );
            },
          ),
        ),
        _sectionPadding(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return _AdaptiveFieldRow(
                constraints: constraints,
                children: <Widget>[
                  AppTextField(
                    fieldKey: const Key('download-selection-min-seeders'),
                    controller: _minSeedersController,
                    label: l10n.downloadSelectionMinSeedersLabel,
                    keyboardType: TextInputType.number,
                    validator: _validateMinSeeders,
                    onChanged: (_) => _handleNumericTextChanged(),
                  ),
                  AppTextField(
                    fieldKey: const Key('download-selection-max-age'),
                    controller: _maxAgeController,
                    label: l10n.downloadSelectionMaxAgeLabel,
                    helperText: l10n.downloadSelectionNoLimitHint,
                    keyboardType: TextInputType.number,
                    validator: _validateMaxAge,
                    onChanged: (_) => _handleNumericTextChanged(),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKeywordSection(DownloadSelectionPolicyState state) {
    final l10n = AppLocalizations.of(context);
    final rules = state.draft;
    final matchError =
        _showRuleErrors && !rules.matchTitle && !rules.matchDescription;
    return AppSettingsGroup(
      key: const Key('download-selection-keyword-section'),
      header: l10n.downloadSelectionKeywordSection,
      children: [
        AppSettingCell(
          title: l10n.downloadSelectionMatchTitle,
          subtitle: l10n.downloadSelectionMatchTitleHint,
          trailing: AppSwitch(
            key: const Key('download-selection-match-title'),
            value: rules.matchTitle,
            onChanged: rules.matchDescription
                ? (value) => _updateRules(rules.copyWith(matchTitle: value))
                : null,
          ),
        ),
        AppSettingCell(
          title: l10n.downloadSelectionMatchDescription,
          subtitle: l10n.downloadSelectionMatchDescriptionHint,
          trailing: AppSwitch(
            key: const Key('download-selection-match-description'),
            value: rules.matchDescription,
            onChanged: rules.matchTitle
                ? (value) =>
                      _updateRules(rules.copyWith(matchDescription: value))
                : null,
          ),
        ),
        if (matchError)
          _sectionPadding(
            child: _RuleWarning(l10n.downloadSelectionMatchFieldRequired),
          ),
        _sectionPadding(
          child: _KeywordGroupList(
            key: const Key('download-selection-required-groups'),
            title: l10n.downloadSelectionRequiredGroups,
            description: l10n.downloadSelectionRequiredGroupsHint,
            groups: rules.requiredGroups,
            addLabel: l10n.downloadSelectionAddRequiredGroup,
            mobile: widget.mobile,
            onAdd: () => unawaited(_addKeywordGroup(required: true)),
            onEdit: (index) =>
                unawaited(_editKeywordGroup(required: true, index: index)),
            onRemove: (index) {
              final next = List<DownloadSelectionKeywordGroupDto>.from(
                rules.requiredGroups,
              )..removeAt(index);
              _updateRules(rules.copyWith(requiredGroups: next));
            },
          ),
        ),
        _sectionPadding(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _KeywordGroupHeader(
                      title: l10n.downloadSelectionExcludedTerms,
                      description: l10n.downloadSelectionExcludedTermsHint,
                    ),
                  ),
                  _TextAction(
                    key: const Key('download-selection-excluded-terms-edit'),
                    label: l10n.commonEdit,
                    onTap: () => unawaited(_editExcludedTerms(rules)),
                  ),
                ],
              ),
              SizedBox(height: context.appSpacing.sm),
              _buildStringPills(
                rules.excludedTerms,
                emptyLabel: l10n.downloadSelectionNoExcludedTerms,
              ),
            ],
          ),
        ),
        _sectionPadding(
          child: _KeywordGroupList(
            key: const Key('download-selection-preferred-groups'),
            title: l10n.downloadSelectionPreferredGroups,
            description: l10n.downloadSelectionPreferredGroupsHint,
            groups: rules.preferredGroups,
            addLabel: l10n.downloadSelectionAddPreferredGroup,
            ordered: true,
            mobile: widget.mobile,
            onAdd: () => unawaited(_addKeywordGroup(required: false)),
            onEdit: (index) =>
                unawaited(_editKeywordGroup(required: false, index: index)),
            onRemove: (index) {
              final next = List<DownloadSelectionKeywordGroupDto>.from(
                rules.preferredGroups,
              )..removeAt(index);
              _updateRules(rules.copyWith(preferredGroups: next));
            },
            onMove: (from, to) =>
                _moveGroup(required: false, from: from, to: to),
          ),
        ),
      ],
    );
  }

  Widget _buildRankingSection(
    DownloadSelectionPolicyState state,
    List<IndexerEntryDto> indexers, {
    required bool indexerCatalogAvailable,
  }) {
    final l10n = AppLocalizations.of(context);
    final rules = state.draft;
    final mustConfigurePriority =
        rules.ranking.contains(DownloadSelectionRanking.indexerPriority) &&
        rules.indexerPriorityNames.isEmpty;
    final availableNames = indexers
        .map((item) => item.name)
        .toList(growable: false);
    final unknownPriorityNames = indexerCatalogAvailable
        ? rules.indexerPriorityNames
              .where(
                (name) => !availableNames.any(
                  (item) => item.toLowerCase() == name.toLowerCase(),
                ),
              )
              .toList(growable: false)
        : const <String>[];
    return AppSettingsGroup(
      key: const Key('download-selection-ranking-section'),
      header: l10n.downloadSelectionRankingSection,
      footer: l10n.downloadSelectionRankingHint,
      children: [
        _sectionPadding(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < rules.ranking.length; index++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index == rules.ranking.length - 1
                        ? 0
                        : context.appSpacing.sm,
                  ),
                  child: _RankingRow(
                    index: index,
                    label: _rankingLabel(rules.ranking[index]),
                    canMoveUp: index > 0,
                    canMoveDown: index < rules.ranking.length - 1,
                    canRemove: rules.ranking.length > 1,
                    mobile: widget.mobile,
                    onMoveUp: () => _moveRanking(index, index - 1),
                    onMoveDown: () => _moveRanking(index, index + 1),
                    onRemove: () => _removeRanking(index),
                  ),
                ),
              if (rules.ranking.length <
                  DownloadSelectionRanking.values.length) ...[
                SizedBox(height: context.appSpacing.md),
                Wrap(
                  spacing: context.appSpacing.sm,
                  runSpacing: context.appSpacing.xs,
                  children: [
                    for (final ranking in DownloadSelectionRanking.values)
                      if (!rules.ranking.contains(ranking))
                        AppPillButton(
                          key: Key(
                            'download-selection-ranking-add-${ranking.apiValue}',
                          ),
                          label: '+ ${_rankingLabel(ranking)}',
                          onTap: () => _updateRules(
                            rules.copyWith(
                              ranking: <DownloadSelectionRanking>[
                                ...rules.ranking,
                                ranking,
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ],
              if (_showRuleErrors && mustConfigurePriority) ...[
                SizedBox(height: context.appSpacing.sm),
                _RuleWarning(l10n.downloadSelectionIndexerPriorityRequired),
              ],
            ],
          ),
        ),
        if (rules.ranking.contains(DownloadSelectionRanking.indexerPriority))
          _sectionPadding(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FieldLabel(
                        l10n.downloadSelectionPriorityIndexers,
                      ),
                    ),
                    _TextAction(
                      key: const Key(
                        'download-selection-priority-indexers-edit',
                      ),
                      label: l10n.commonEdit,
                      onTap: () =>
                          unawaited(_editPriorityIndexers(rules, indexers)),
                    ),
                  ],
                ),
                SizedBox(height: context.appSpacing.sm),
                if (rules.indexerPriorityNames.isEmpty)
                  Text(
                    l10n.downloadSelectionNoPriorityIndexers,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.muted,
                    ),
                  )
                else
                  Column(
                    children: [
                      for (
                        var index = 0;
                        index < rules.indexerPriorityNames.length;
                        index++
                      )
                        _PriorityIndexerRow(
                          index: index,
                          name: rules.indexerPriorityNames[index],
                          canMoveUp: index > 0,
                          canMoveDown:
                              index < rules.indexerPriorityNames.length - 1,
                          mobile: widget.mobile,
                          onMoveUp: () =>
                              _movePriorityIndexer(index, index - 1),
                          onMoveDown: () =>
                              _movePriorityIndexer(index, index + 1),
                          onRemove: () => _removePriorityIndexer(index),
                        ),
                    ],
                  ),
                if (unknownPriorityNames.isNotEmpty) ...[
                  SizedBox(height: context.appSpacing.sm),
                  _RuleWarning(
                    l10n.downloadSelectionIndexerUnavailableWarning(
                      unknownPriorityNames.join(', '),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewSection(DownloadSelectionPolicyState state) {
    final l10n = AppLocalizations.of(context);
    final preview = state.preview;
    return AppSettingsGroup(
      key: const Key('download-selection-preview-section'),
      header: l10n.downloadSelectionPreviewSection,
      footer: l10n.downloadSelectionPreviewHint,
      children: [
        _sectionPadding(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final field = AppTextField(
                fieldKey: const Key('download-selection-preview-movie-number'),
                controller: _previewMovieController,
                label: l10n.downloadSelectionMovieNumber,
                hintText: l10n.downloadSelectionMovieNumberHint,
                helperText: _previewNormalizedMovieNumber == null
                    ? null
                    : l10n.downloadSelectionMovieNumberRecognized(
                        _previewNormalizedMovieNumber!,
                      ),
                textInputAction: TextInputAction.search,
                onChanged: (_) {
                  _previewMovieInputVersion++;
                  if (_previewValidationMessage != null ||
                      _previewNormalizedMovieNumber != null) {
                    setState(() {
                      _previewValidationMessage = null;
                      _previewNormalizedMovieNumber = null;
                    });
                  }
                  ref
                      .read(downloadSelectionPolicyProvider.notifier)
                      .clearPreview();
                },
                onFieldSubmitted: (_) => unawaited(_preview(state)),
              );
              final previewBusy =
                  _isParsingPreviewMovieNumber || state.isPreviewing;
              final button = AppButton(
                key: const Key('download-selection-preview-button'),
                label: previewBusy
                    ? l10n.downloadSelectionPreviewing
                    : l10n.downloadSelectionRunPreview,
                variant: AppButtonVariant.primary,
                isLoading: previewBusy,
                onPressed: previewBusy
                    ? null
                    : () => unawaited(_preview(state)),
              );
              final error = _previewValidationMessage;
              final content = constraints.maxWidth < 520
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        field,
                        if (error != null) ...[
                          SizedBox(height: context.appSpacing.xs),
                          _RuleWarning(error),
                        ],
                        SizedBox(height: context.appSpacing.sm),
                        button,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              field,
                              if (error != null) ...[
                                SizedBox(height: context.appSpacing.xs),
                                _RuleWarning(error),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: context.appSpacing.sm),
                        Padding(
                          padding: EdgeInsets.only(top: context.appSpacing.xl),
                          child: button,
                        ),
                      ],
                    );
              return content;
            },
          ),
        ),
        if (state.previewError != null)
          _sectionPadding(
            child: AppInlineErrorBanner(
              key: const Key('download-selection-preview-error'),
              message: state.previewError!,
              tone: AppInlineErrorTone.error,
            ),
          ),
        if (preview != null)
          _sectionPadding(
            child: _DownloadSelectionPreviewResult(preview: preview),
          )
        else if (!state.isPreviewing)
          _sectionPadding(
            child: Text(
              l10n.downloadSelectionPreviewEmpty,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.muted,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSaveFooter(DownloadSelectionPolicyState state, bool dirty) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final badge = _buildUnsavedBadge(dirty);
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          spacing.md,
          spacing.sm,
          spacing.md,
          spacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          border: Border(top: BorderSide(color: colors.divider)),
        ),
        child: Row(
          children: [
            ?badge,
            const Spacer(),
            ..._buildPolicyButtons(
              state,
              dirty,
              buttonSize: AppButtonSize.medium,
            ),
          ],
        ),
      ),
    );
  }

  /// 桌面端标题行：左侧分类标题、右侧操作区，固定在滚动区之外。
  ///
  /// 保存动作放在标题行而不是页面底部，滚动长表单时始终可见；底部不再保留
  /// 灰色保存带（它与页面底色同色，会把上方的白色分组卡拦腰切断）。
  Widget _buildDesktopHeader(DownloadSelectionPolicyState? state, bool dirty) {
    final spacing = context.appSpacing;
    final badge = _buildUnsavedBadge(dirty);
    return Padding(
      key: const Key('download-selection-desktop-header'),
      padding: EdgeInsets.only(right: spacing.lg, bottom: spacing.lg),
      child: Row(
        children: [
          Expanded(child: _buildDesktopTitleText()),
          if (badge != null) ...[badge, SizedBox(width: spacing.md)],
          if (state != null)
            ..._buildPolicyButtons(
              state,
              dirty,
              buttonSize: AppButtonSize.small,
            ),
        ],
      ),
    );
  }

  /// 分类标题，与系统设置页其它分类的标题保持同一套排版。
  Widget _buildDesktopTitleText() {
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.configTabDownloadSelection,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s18,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
    );
  }

  /// 加载 / 错误态的外壳：桌面端保留标题行，避免操作区整块消失；
  /// 移动端维持原样，只有内容。
  Widget _buildBodyShell(Widget child) {
    if (widget.mobile) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDesktopHeader(null, false),
        Expanded(child: child),
      ],
    );
  }

  /// 未保存徽标；没有改动时返回 null。
  Widget? _buildUnsavedBadge(bool dirty) {
    if (!dirty) return null;
    final l10n = AppLocalizations.of(context);
    return AppBadge(
      key: const Key('download-selection-unsaved-badge'),
      label: l10n.configUnsavedBadge,
      tone: AppBadgeTone.warning,
      size: AppBadgeSize.compact,
    );
  }

  /// 保存操作组：放弃更改 + 保存策略。
  ///
  /// 桌面端挂在标题行右侧，移动端挂在底部操作栏，两端共用同一组动作。
  List<Widget> _buildPolicyButtons(
    DownloadSelectionPolicyState state,
    bool dirty, {
    required AppButtonSize buttonSize,
  }) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return <Widget>[
      if (dirty) ...[
        AppButton(
          key: const Key('download-selection-discard-button'),
          label: l10n.downloadSelectionDiscard,
          variant: AppButtonVariant.ghost,
          size: buttonSize,
          onPressed: state.isSaving ? null : _discard,
        ),
        SizedBox(width: spacing.sm),
      ],
      AppButton(
        key: const Key('download-selection-save-button'),
        label: l10n.downloadSelectionSave,
        variant: AppButtonVariant.primary,
        size: buttonSize,
        isLoading: state.isSaving,
        onPressed: state.isSaving || !dirty
            ? null
            : () => unawaited(_save(state)),
      ),
    ];
  }

  /// 放弃未保存的草稿：回滚到已保存策略，并把输入框同步回已保存值。
  void _discard() {
    // saved.version 不变时 _syncControllers 会提前返回，输入框会残留已废弃的
    // 文本；先重置版本号，下一次 build 才会重新同步控制器。
    _initializedVersion = -1;
    _previewMovieInputVersion++;
    setState(() {
      _localTextEdits = false;
      _showRuleErrors = false;
      _previewValidationMessage = null;
      _previewNormalizedMovieNumber = null;
    });
    ref.read(downloadSelectionPolicyProvider.notifier).discardDraft();
  }

  Future<void> _save(DownloadSelectionPolicyState state) async {
    setState(() => _showRuleErrors = true);
    final formValid = _formKey.currentState?.validate() ?? false;
    final ruleErrors = _ruleValidationErrors(state.draft);
    if (!formValid || ruleErrors.isNotEmpty) return;
    try {
      final saved = await ref
          .read(downloadSelectionPolicyProvider.notifier)
          .save();
      if (!mounted) return;
      if (saved) {
        setState(() {
          _localTextEdits = false;
          _showRuleErrors = false;
        });
        showToast(AppLocalizations.of(context).downloadSelectionSaved);
      }
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.downloadSelectionSaveFailed,
          l10n: l10n,
        ),
      );
    }
  }

  Future<void> _preview(DownloadSelectionPolicyState state) async {
    if (_isParsingPreviewMovieNumber || state.isPreviewing) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _showRuleErrors = true);
    final formValid = _formKey.currentState?.validate() ?? false;
    final ruleErrors = _ruleValidationErrors(state.draft);
    final rawMovieNumber = _previewMovieController.text.trim();
    if (!formValid || ruleErrors.isNotEmpty) return;
    if (rawMovieNumber.isEmpty) {
      setState(() {
        _previewValidationMessage = l10n.downloadSelectionMovieNumberRequired;
      });
      return;
    }
    final inputVersion = _previewMovieInputVersion;
    setState(() {
      _previewValidationMessage = null;
      _previewNormalizedMovieNumber = null;
      _isParsingPreviewMovieNumber = true;
    });
    try {
      final parsed = await ref
          .read(moviesApiProvider)
          .parseMovieNumber(query: rawMovieNumber);
      if (!_isCurrentPreviewMovieInput(inputVersion, rawMovieNumber)) return;
      final movieNumber = parsed.movieNumber?.trim() ?? '';
      if (!parsed.parsed || movieNumber.isEmpty) {
        setState(() {
          _previewValidationMessage = l10n.downloadMovieNumberUnrecognized;
        });
        return;
      }
      setState(() {
        _previewNormalizedMovieNumber = movieNumber;
        _isParsingPreviewMovieNumber = false;
      });
      await ref
          .read(downloadSelectionPolicyProvider.notifier)
          .preview(movieNumber, inputMovieNumber: rawMovieNumber);
    } catch (error) {
      if (!_isCurrentPreviewMovieInput(inputVersion, rawMovieNumber)) return;
      setState(() {
        _previewValidationMessage = apiErrorMessage(
          error,
          fallback: l10n.downloadMovieNumberQueryFailed,
          l10n: l10n,
        );
      });
    } finally {
      if (mounted && _isParsingPreviewMovieNumber) {
        setState(() => _isParsingPreviewMovieNumber = false);
      }
    }
  }

  bool _isCurrentPreviewMovieInput(int version, String rawMovieNumber) {
    return mounted &&
        version == _previewMovieInputVersion &&
        _previewMovieController.text.trim() == rawMovieNumber;
  }

  Future<void> _reloadAfterConflict() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.downloadSelectionReloadTitle,
      message: l10n.downloadSelectionReloadMessage,
      confirmLabel: l10n.downloadSelectionReloadConfirm,
      confirmKey: const Key('download-selection-reload-confirm'),
    );
    if (!confirmed || !mounted) return;
    await ref.read(downloadSelectionPolicyProvider.notifier).reload();
  }

  void _handleNumericTextChanged() {
    setState(() => _localTextEdits = true);
    ref.read(downloadSelectionPolicyProvider.notifier).clearPreview();
    _applyTextFields();
  }

  void _applyTextFields() {
    final current = ref.read(downloadSelectionPolicyProvider).value;
    if (current == null) return;
    final minSize = _parseGiB(_minSizeController.text);
    final maxSizeText = _maxSizeController.text.trim();
    final maxSize = maxSizeText.isEmpty ? null : _parseGiB(maxSizeText);
    final minSeeders = int.tryParse(_minSeedersController.text.trim());
    final maxAgeText = _maxAgeController.text.trim();
    final maxAge = maxAgeText.isEmpty ? null : int.tryParse(maxAgeText);
    if (minSize == null ||
        (maxSizeText.isNotEmpty && maxSize == null) ||
        minSeeders == null ||
        (maxAgeText.isNotEmpty && maxAge == null)) {
      return;
    }
    ref
        .read(downloadSelectionPolicyProvider.notifier)
        .updateDraft(
          current.draft.copyWith(
            minSizeBytes: minSize,
            maxSizeBytes: maxSize,
            minSeeders: minSeeders,
            maxAgeDays: maxAge,
          ),
        );
  }

  Future<void> _editIndexerNames({
    required DownloadSelectionRulesDto rules,
    required List<String> availableNames,
  }) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDownloadSelectionIndexerPicker(
      context,
      title: l10n.downloadSelectionIndexerNamesLabel,
      description: l10n.downloadSelectionIndexerNamesPickerHint,
      availableNames: availableNames,
      selectedNames: rules.indexerNames,
    );
    if (result != null) {
      _updateRules(rules.copyWith(indexerNames: result));
    }
  }

  Future<void> _editPriorityIndexers(
    DownloadSelectionRulesDto rules,
    List<IndexerEntryDto> indexers,
  ) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDownloadSelectionIndexerPicker(
      context,
      title: l10n.downloadSelectionPriorityIndexers,
      description: l10n.downloadSelectionPriorityIndexersHint,
      availableNames: indexers.map((item) => item.name).toList(growable: false),
      selectedNames: rules.indexerPriorityNames,
      ordered: true,
    );
    if (result != null) {
      _updateRules(rules.copyWith(indexerPriorityNames: result));
    }
  }

  Future<void> _addKeywordGroup({required bool required}) async {
    final l10n = AppLocalizations.of(context);
    final group = await showDownloadSelectionKeywordGroupEditor(
      context,
      title: required
          ? l10n.downloadSelectionAddRequiredGroup
          : l10n.downloadSelectionAddPreferredGroup,
    );
    if (group == null) return;
    final current = ref.read(downloadSelectionPolicyProvider).value;
    if (current == null) return;
    final rules = current.draft;
    _updateRules(
      required
          ? rules.copyWith(
              requiredGroups: <DownloadSelectionKeywordGroupDto>[
                ...rules.requiredGroups,
                group,
              ],
            )
          : rules.copyWith(
              preferredGroups: <DownloadSelectionKeywordGroupDto>[
                ...rules.preferredGroups,
                group,
              ],
            ),
    );
  }

  Future<void> _editKeywordGroup({
    required bool required,
    required int index,
  }) async {
    final current = ref.read(downloadSelectionPolicyProvider).value;
    if (current == null) return;
    final rules = current.draft;
    final groups = required ? rules.requiredGroups : rules.preferredGroups;
    if (index < 0 || index >= groups.length) return;
    final l10n = AppLocalizations.of(context);
    final group = await showDownloadSelectionKeywordGroupEditor(
      context,
      title: l10n.downloadSelectionEditKeywordGroup,
      initialGroup: groups[index],
    );
    if (group == null) return;
    final latest = ref.read(downloadSelectionPolicyProvider).value;
    if (latest == null) return;
    final latestRules = latest.draft;
    final next = List<DownloadSelectionKeywordGroupDto>.from(
      required ? latestRules.requiredGroups : latestRules.preferredGroups,
    );
    if (index >= next.length) return;
    next[index] = group;
    _updateRules(
      required
          ? latestRules.copyWith(requiredGroups: next)
          : latestRules.copyWith(preferredGroups: next),
    );
  }

  Future<void> _editExcludedTerms(DownloadSelectionRulesDto rules) async {
    final l10n = AppLocalizations.of(context);
    final group = await showDownloadSelectionKeywordGroupEditor(
      context,
      title: l10n.downloadSelectionExcludedTerms,
      initialGroup: DownloadSelectionKeywordGroupDto(
        terms: rules.excludedTerms,
      ),
    );
    if (group == null) return;
    final latest = ref.read(downloadSelectionPolicyProvider).value;
    if (latest == null) return;
    _updateRules(latest.draft.copyWith(excludedTerms: group.terms));
  }

  void _moveGroup({
    required bool required,
    required int from,
    required int to,
  }) {
    final current = ref.read(downloadSelectionPolicyProvider).value;
    if (current == null) return;
    final rules = current.draft;
    final source = required ? rules.requiredGroups : rules.preferredGroups;
    if (from < 0 || to < 0 || from >= source.length || to >= source.length) {
      return;
    }
    final next = List<DownloadSelectionKeywordGroupDto>.from(source);
    final item = next.removeAt(from);
    next.insert(to, item);
    _updateRules(
      required
          ? rules.copyWith(requiredGroups: next)
          : rules.copyWith(preferredGroups: next),
    );
  }

  void _moveRanking(int from, int to) {
    final current = ref.read(downloadSelectionPolicyProvider).value;
    if (current == null) return;
    final ranking = List<DownloadSelectionRanking>.from(current.draft.ranking);
    if (from < 0 || to < 0 || from >= ranking.length || to >= ranking.length) {
      return;
    }
    final item = ranking.removeAt(from);
    ranking.insert(to, item);
    _updateRules(current.draft.copyWith(ranking: ranking));
  }

  void _removeRanking(int index) {
    final current = ref.read(downloadSelectionPolicyProvider).value;
    if (current == null || current.draft.ranking.length <= 1) return;
    final ranking = List<DownloadSelectionRanking>.from(current.draft.ranking)
      ..removeAt(index);
    _updateRules(current.draft.copyWith(ranking: ranking));
  }

  void _movePriorityIndexer(int from, int to) {
    final current = ref.read(downloadSelectionPolicyProvider).value;
    if (current == null) return;
    final names = List<String>.from(current.draft.indexerPriorityNames);
    if (from < 0 || to < 0 || from >= names.length || to >= names.length) {
      return;
    }
    final item = names.removeAt(from);
    names.insert(to, item);
    _updateRules(current.draft.copyWith(indexerPriorityNames: names));
  }

  void _removePriorityIndexer(int index) {
    final current = ref.read(downloadSelectionPolicyProvider).value;
    if (current == null) return;
    final names = List<String>.from(current.draft.indexerPriorityNames)
      ..removeAt(index);
    _updateRules(current.draft.copyWith(indexerPriorityNames: names));
  }

  void _updateRules(DownloadSelectionRulesDto rules) {
    ref.read(downloadSelectionPolicyProvider.notifier).updateDraft(rules);
  }

  List<String> _ruleValidationErrors(DownloadSelectionRulesDto rules) {
    final l10n = AppLocalizations.of(context);
    final errors = <String>[];
    if (!rules.matchTitle && !rules.matchDescription) {
      errors.add(l10n.downloadSelectionMatchFieldRequired);
    }
    if (rules.ranking.isEmpty) {
      errors.add(l10n.downloadSelectionRankingRequired);
    }
    if (rules.ranking.contains(DownloadSelectionRanking.indexerPriority) &&
        rules.indexerPriorityNames.isEmpty) {
      errors.add(l10n.downloadSelectionIndexerPriorityRequired);
    }
    final indexers = ref.read(indexerSettingsProvider).value?.saved.indexers;
    if (indexers != null) {
      final availableNames = indexers
          .map((item) => item.name.toLowerCase())
          .toSet();
      final unavailable = <String>{
        for (final name in <String>[
          ...rules.indexerNames,
          ...rules.indexerPriorityNames,
        ])
          if (!availableNames.contains(name.toLowerCase())) name,
      };
      if (unavailable.isNotEmpty) {
        errors.add(
          l10n.downloadSelectionIndexerUnavailableWarning(
            unavailable.join(', '),
          ),
        );
      }
    }
    return errors;
  }

  String? _validateMinSize(String? value) {
    final l10n = AppLocalizations.of(context);
    final bytes = _parseGiB(value ?? '');
    if (bytes == null) return l10n.downloadSelectionSizeInvalid;
    if (bytes < 0) return l10n.downloadSelectionSizeInvalid;
    return null;
  }

  String? _validateMaxSize(String? value) {
    final l10n = AppLocalizations.of(context);
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final bytes = _parseGiB(text);
    if (bytes == null || bytes <= 0) {
      return l10n.downloadSelectionSizeInvalid;
    }
    final minBytes = _parseGiB(_minSizeController.text) ?? 0;
    if (bytes < minBytes) {
      return l10n.downloadSelectionMaxSizeTooSmall;
    }
    return null;
  }

  String? _validateMinSeeders(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed < 0) {
      return AppLocalizations.of(context).downloadSelectionSeedersInvalid;
    }
    return null;
  }

  String? _validateMaxAge(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    if (parsed == null || parsed < 1 || parsed > 36500) {
      return AppLocalizations.of(context).downloadSelectionMaxAgeInvalid;
    }
    return null;
  }

  Widget _buildStringPills(
    List<String> values, {
    required String emptyLabel,
    Set<String> warningNames = const <String>{},
  }) {
    if (values.isEmpty) {
      return Text(
        emptyLabel,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          tone: AppTextTone.muted,
        ),
      );
    }
    return Wrap(
      spacing: context.appSpacing.sm,
      runSpacing: context.appSpacing.xs,
      children: [
        for (final value in values)
          AppPill(
            label: value,
            tone: warningNames.contains(value)
                ? AppPillTone.warning
                : AppPillTone.neutral,
            size: AppPillSize.compact,
          ),
      ],
    );
  }

  String _rankingLabel(DownloadSelectionRanking ranking) {
    final l10n = AppLocalizations.of(context);
    return switch (ranking) {
      DownloadSelectionRanking.sizeDesc => l10n.downloadSelectionRankingSize,
      DownloadSelectionRanking.seedersDesc =>
        l10n.downloadSelectionRankingSeeders,
      DownloadSelectionRanking.publishedAtDesc =>
        l10n.downloadSelectionRankingPublishedAt,
      DownloadSelectionRanking.indexerPriority =>
        l10n.downloadSelectionRankingIndexerPriority,
    };
  }

  Widget _sectionPadding({required Widget child}) {
    final spacing = context.appSpacing;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      child: child,
    );
  }

  Widget _unitSuffix(
    BuildContext context, {
    required Key key,
    required String unit,
  }) {
    final spacing = context.appSpacing;
    return Padding(
      padding: EdgeInsetsDirectional.only(start: spacing.xs, end: spacing.md),
      child: Text(
        unit,
        key: key,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.medium,
          tone: AppTextTone.secondary,
        ),
      ),
    );
  }

  static int? _parseGiB(String value) {
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
    return (parsed * _bytesPerGiB).round();
  }

  static String _formatGiB(int bytes) {
    final value = bytes / _bytesPerGiB;
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class _AdaptiveFieldRow extends StatelessWidget {
  const _AdaptiveFieldRow({required this.constraints, required this.children});

  final BoxConstraints constraints;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (constraints.maxWidth < 420) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) SizedBox(height: context.appSpacing.md),
            children[index],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) SizedBox(width: context.appSpacing.md),
          Expanded(child: children[index]),
        ],
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        tone: AppTextTone.secondary,
      ),
    );
  }
}

class _RuleWarning extends StatelessWidget {
  const _RuleWarning(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        tone: AppTextTone.warning,
      ),
    );
  }
}

class _VersionConflictBanner extends StatelessWidget {
  const _VersionConflictBanner({required this.onReload});

  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('download-selection-version-conflict'),
      padding: EdgeInsets.all(context.appSpacing.md),
      decoration: BoxDecoration(
        color: context.appColors.warningSurface,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.downloadSelectionVersionConflict,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.warning,
              ),
            ),
          ),
          SizedBox(width: context.appSpacing.sm),
          AppButton(
            key: const Key('download-selection-reload-button'),
            label: l10n.downloadSelectionReloadLatest,
            size: AppButtonSize.xSmall,
            onPressed: onReload,
          ),
        ],
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppTextButton(
      label: label,
      onPressed: onTap,
      size: AppTextButtonSize.xSmall,
      emphasis: AppTextButtonEmphasis.accent,
    );
  }
}

class _KeywordGroupHeader extends StatelessWidget {
  const _KeywordGroupHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.medium,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: context.appSpacing.xs),
        Text(
          description,
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

enum _PolicyRowAction { moveUp, moveDown, edit, remove }

Future<_PolicyRowAction?> _showPolicyRowActions(
  BuildContext context, {
  required String title,
  required Key drawerKey,
  required bool canMoveUp,
  required bool canMoveDown,
  required bool canRemove,
  bool canEdit = false,
}) {
  final l10n = AppLocalizations.of(context);
  return showAppActionMenu<_PolicyRowAction>(
    context: context,
    presentation: AppMenuPresentation.bottomDrawer,
    drawerKey: drawerKey,
    title: title,
    items: <AppMenuItem<_PolicyRowAction>>[
      AppMenuItem(
        value: _PolicyRowAction.moveUp,
        label: l10n.commonMoveUp,
        icon: Icons.arrow_upward_rounded,
        enabled: canMoveUp,
      ),
      AppMenuItem(
        value: _PolicyRowAction.moveDown,
        label: l10n.commonMoveDown,
        icon: Icons.arrow_downward_rounded,
        enabled: canMoveDown,
      ),
      if (canEdit)
        AppMenuItem(
          value: _PolicyRowAction.edit,
          label: l10n.commonEdit,
          icon: Icons.edit_outlined,
        ),
      AppMenuItem(
        value: _PolicyRowAction.remove,
        label: l10n.commonDelete,
        icon: Icons.delete_outline_rounded,
        tone: AppTextTone.error,
        enabled: canRemove,
      ),
    ],
  );
}

class _KeywordGroupList extends StatelessWidget {
  const _KeywordGroupList({
    super.key,
    required this.title,
    required this.description,
    required this.groups,
    required this.addLabel,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
    this.ordered = false,
    required this.mobile,
    this.onMove,
  });

  final String title;
  final String description;
  final List<DownloadSelectionKeywordGroupDto> groups;
  final String addLabel;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;
  final bool ordered;
  final bool mobile;
  final void Function(int from, int to)? onMove;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KeywordGroupHeader(title: title, description: description),
        if (groups.isNotEmpty) SizedBox(height: spacing.sm),
        for (var index = 0; index < groups.length; index++) ...[
          if (index > 0) SizedBox(height: spacing.sm),
          Container(
            padding: EdgeInsets.all(spacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: context.appRadius.mdBorder,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBadge(
                  label: ordered
                      ? '${index + 1}'
                      : AppLocalizations.of(
                          context,
                        ).downloadSelectionGroupNumber(index + 1),
                  tone: AppBadgeTone.neutral,
                  size: AppBadgeSize.compact,
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groups[index].label?.trim().isNotEmpty ?? false
                            ? groups[index].label!
                            : AppLocalizations.of(
                                context,
                              ).downloadSelectionUnnamedGroup,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          weight: AppTextWeight.medium,
                          tone: AppTextTone.primary,
                        ),
                      ),
                      SizedBox(height: spacing.xs),
                      Wrap(
                        spacing: spacing.xs,
                        runSpacing: spacing.xs,
                        children: [
                          for (final term in groups[index].terms)
                            AppPill(label: term, size: AppPillSize.compact),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: spacing.xs),
                if (mobile)
                  AppIconButton(
                    key: Key('download-selection-group-more-$index'),
                    tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                    size: AppIconButtonSize.regular,
                    onPressed: () => unawaited(_showActions(context, index)),
                    icon: const Icon(Icons.more_horiz_rounded),
                  )
                else ...[
                  if (ordered && onMove != null) ...[
                    AppIconButton(
                      key: Key('download-selection-group-up-$index'),
                      tooltip: AppLocalizations.of(context).commonMoveUp,
                      size: AppIconButtonSize.mini,
                      onPressed: index == 0
                          ? null
                          : () => onMove!(index, index - 1),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                    AppIconButton(
                      key: Key('download-selection-group-down-$index'),
                      tooltip: AppLocalizations.of(context).commonMoveDown,
                      size: AppIconButtonSize.mini,
                      onPressed: index == groups.length - 1
                          ? null
                          : () => onMove!(index, index + 1),
                      icon: const Icon(Icons.arrow_downward_rounded),
                    ),
                  ],
                  AppIconButton(
                    key: Key('download-selection-group-edit-$index'),
                    tooltip: AppLocalizations.of(context).commonEdit,
                    size: AppIconButtonSize.mini,
                    onPressed: () => onEdit(index),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  AppIconButton(
                    key: Key('download-selection-group-remove-$index'),
                    tooltip: AppLocalizations.of(context).commonDelete,
                    size: AppIconButtonSize.mini,
                    onPressed: () => onRemove(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
          ),
        ],
        SizedBox(height: spacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppButton(
            label: addLabel,
            size: AppButtonSize.xSmall,
            icon: const Icon(Icons.add_rounded),
            onPressed: onAdd,
          ),
        ),
      ],
    );
  }

  Future<void> _showActions(BuildContext context, int index) async {
    final group = groups[index];
    final label = group.label?.trim();
    final action = await _showPolicyRowActions(
      context,
      title: label?.isNotEmpty ?? false
          ? label!
          : AppLocalizations.of(
              context,
            ).downloadSelectionGroupNumber(index + 1),
      drawerKey: Key('download-selection-group-actions-$index'),
      canMoveUp: ordered && onMove != null && index > 0,
      canMoveDown: ordered && onMove != null && index < groups.length - 1,
      canEdit: true,
      canRemove: true,
    );
    if (!context.mounted) return;
    switch (action) {
      case _PolicyRowAction.moveUp:
        onMove?.call(index, index - 1);
      case _PolicyRowAction.moveDown:
        onMove?.call(index, index + 1);
      case _PolicyRowAction.edit:
        onEdit(index);
      case _PolicyRowAction.remove:
        onRemove(index);
      case null:
        break;
    }
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.index,
    required this.label,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.canRemove,
    required this.mobile,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final String label;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool canRemove;
  final bool mobile;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Row(
        children: [
          AppBadge(
            label: '${index + 1}',
            size: AppBadgeSize.compact,
            tone: AppBadgeTone.neutral,
          ),
          SizedBox(width: context.appSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                tone: AppTextTone.primary,
              ),
            ),
          ),
          if (mobile)
            AppIconButton(
              key: Key('download-selection-ranking-more-$index'),
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              size: AppIconButtonSize.regular,
              onPressed: () => unawaited(_showActions(context)),
              icon: const Icon(Icons.more_horiz_rounded),
            )
          else ...[
            AppIconButton(
              key: Key('download-selection-ranking-up-$index'),
              tooltip: l10n.commonMoveUp,
              size: AppIconButtonSize.mini,
              onPressed: canMoveUp ? onMoveUp : null,
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
            AppIconButton(
              key: Key('download-selection-ranking-down-$index'),
              tooltip: l10n.commonMoveDown,
              size: AppIconButtonSize.mini,
              onPressed: canMoveDown ? onMoveDown : null,
              icon: const Icon(Icons.arrow_downward_rounded),
            ),
            AppIconButton(
              key: Key('download-selection-ranking-remove-$index'),
              tooltip: l10n.commonDelete,
              size: AppIconButtonSize.mini,
              onPressed: canRemove ? onRemove : null,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final action = await _showPolicyRowActions(
      context,
      title: label,
      drawerKey: Key('download-selection-ranking-actions-$index'),
      canMoveUp: canMoveUp,
      canMoveDown: canMoveDown,
      canRemove: canRemove,
    );
    if (!context.mounted) return;
    switch (action) {
      case _PolicyRowAction.moveUp:
        onMoveUp();
      case _PolicyRowAction.moveDown:
        onMoveDown();
      case _PolicyRowAction.remove:
        onRemove();
      case _PolicyRowAction.edit:
      case null:
        break;
    }
  }
}

class _PriorityIndexerRow extends StatelessWidget {
  const _PriorityIndexerRow({
    required this.index,
    required this.name,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.mobile,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final String name;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool mobile;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: context.appSpacing.xs),
      child: Row(
        children: [
          AppBadge(label: '${index + 1}', size: AppBadgeSize.compact),
          SizedBox(width: context.appSpacing.sm),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                tone: AppTextTone.primary,
              ),
            ),
          ),
          if (mobile)
            AppIconButton(
              key: Key('download-selection-priority-indexer-more-$index'),
              tooltip: MaterialLocalizations.of(context).showMenuTooltip,
              size: AppIconButtonSize.regular,
              onPressed: () => unawaited(_showActions(context)),
              icon: const Icon(Icons.more_horiz_rounded),
            )
          else ...[
            AppIconButton(
              tooltip: l10n.commonMoveUp,
              size: AppIconButtonSize.mini,
              onPressed: canMoveUp ? onMoveUp : null,
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
            AppIconButton(
              tooltip: l10n.commonMoveDown,
              size: AppIconButtonSize.mini,
              onPressed: canMoveDown ? onMoveDown : null,
              icon: const Icon(Icons.arrow_downward_rounded),
            ),
            AppIconButton(
              tooltip: l10n.commonDelete,
              size: AppIconButtonSize.mini,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final action = await _showPolicyRowActions(
      context,
      title: name,
      drawerKey: Key('download-selection-priority-indexer-actions-$index'),
      canMoveUp: canMoveUp,
      canMoveDown: canMoveDown,
      canRemove: true,
    );
    if (!context.mounted) return;
    switch (action) {
      case _PolicyRowAction.moveUp:
        onMoveUp();
      case _PolicyRowAction.moveDown:
        onMoveDown();
      case _PolicyRowAction.remove:
        onRemove();
      case _PolicyRowAction.edit:
      case null:
        break;
    }
  }
}

class _DownloadSelectionPreviewResult extends StatelessWidget {
  const _DownloadSelectionPreviewResult({required this.preview});

  final DownloadSelectionPreviewDto preview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return Column(
      key: const Key('download-selection-preview-result'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.xs,
          children: [
            AppPill(
              label: l10n.downloadSelectionPreviewRaw(
                preview.rawCandidateCount,
              ),
              size: AppPillSize.compact,
            ),
            AppPill(
              label: l10n.downloadSelectionPreviewSystem(
                preview.systemCandidateCount,
              ),
              size: AppPillSize.compact,
              tone: AppPillTone.neutral,
            ),
            AppPill(
              label: l10n.downloadSelectionPreviewEligible(
                preview.eligibleCandidateCount,
              ),
              size: AppPillSize.compact,
              tone: AppPillTone.primary,
            ),
            AppPill(
              label: l10n.downloadSelectionPreviewFiltered(
                preview.policyFilteredCount,
              ),
              size: AppPillSize.compact,
              tone: preview.policyFilteredCount > 0
                  ? AppPillTone.warning
                  : AppPillTone.neutral,
            ),
          ],
        ),
        SizedBox(height: spacing.md),
        if (preview.candidates.isEmpty)
          AppEmptyState(message: l10n.downloadSelectionPreviewNoCandidates)
        else
          for (var index = 0; index < preview.candidates.length; index++) ...[
            if (index > 0) SizedBox(height: spacing.sm),
            _PreviewCandidateCard(
              index: index,
              candidate: preview.candidates[index],
              selected:
                  preview.selectedSourceUri != null &&
                  preview.selectedSourceUri ==
                      preview.candidates[index].sourceUri,
            ),
          ],
      ],
    );
  }
}

class _PreviewCandidateCard extends StatelessWidget {
  const _PreviewCandidateCard({
    required this.index,
    required this.candidate,
    required this.selected,
  });

  final int index;
  final DownloadCandidateDto candidate;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final evaluation = candidate.selectionEvaluation;
    return Container(
      key: Key('download-selection-preview-candidate-$index'),
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: selected
            ? context.appColors.selectionSurface
            : context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(
          color: selected
              ? context.appColors.selectionBorder
              : context.appColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selected) ...[
            AppBadge(
              label: AppLocalizations.of(
                context,
              ).downloadSelectionPreviewSelected,
              tone: AppBadgeTone.primary,
              size: AppBadgeSize.compact,
            ),
            SizedBox(height: spacing.sm),
          ],
          Text(
            candidate.title,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          Wrap(
            spacing: spacing.md,
            runSpacing: spacing.xs,
            children: [
              Text(
                candidate.indexerName,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.secondary,
                ),
              ),
              Text(
                formatFileSize(candidate.sizeBytes),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.secondary,
                ),
              ),
              Text(
                AppLocalizations.of(
                  context,
                ).downloadSelectionSeedersValue(candidate.seeders),
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.secondary,
                ),
              ),
            ],
          ),
          if (evaluation != null) ...[
            SizedBox(height: spacing.sm),
            DownloadCandidateSelectionSummary(
              evaluation: evaluation,
              showManualHint: false,
            ),
          ],
        ],
      ),
    );
  }
}
