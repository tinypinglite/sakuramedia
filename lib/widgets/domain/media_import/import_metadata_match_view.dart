import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/media_import/data/import_failed_item_dto.dart';
import 'package:sakuramedia/features/media_import/data/import_metadata_search_dto.dart';
import 'package:sakuramedia/features/media_import/presentation/providers/import_metadata_match_provider.dart';
import 'package:sakuramedia/features/media_import/presentation/providers/media_import_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_left_cover_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/domain/search/catalog_search_field.dart';

/// 失败文件的人工元数据匹配视图：输入番号 → 选择候选 → 提交重试。
///
/// 嵌在失败文件弹层内，作为列表视图的第二步；[onRetried] 由承载组件负责回到
/// 列表并刷新失败项状态。
class ImportMetadataMatchView extends ConsumerStatefulWidget {
  const ImportMetadataMatchView({
    super.key,
    required this.taskRunId,
    required this.item,
    required this.onBack,
    required this.onRetried,
  });

  final int taskRunId;
  final ImportFailedItemDto item;
  final VoidCallback onBack;
  final VoidCallback onRetried;

  @override
  ConsumerState<ImportMetadataMatchView> createState() =>
      _ImportMetadataMatchViewState();
}

class _ImportMetadataMatchViewState
    extends ConsumerState<ImportMetadataMatchView> {
  final TextEditingController _numberController = TextEditingController();
  String? _selectedCandidateId;
  bool _isRetrying = false;

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  void _search() {
    setState(() => _selectedCandidateId = null);
    ref
        .read(
          importMetadataMatchProvider(
            widget.taskRunId,
            widget.item.id,
          ).notifier,
        )
        .search(_numberController.text);
  }

  Future<void> _retry() async {
    final candidateId = _selectedCandidateId;
    if (candidateId == null || _isRetrying) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _isRetrying = true);
    try {
      await ref
          .read(mediaImportApiProvider)
          .retryFailedItem(
            taskRunId: widget.taskRunId,
            itemId: widget.item.id,
            candidateId: candidateId,
          );
      if (!mounted) return;
      showToast(
        l10n.widgetMediaImportRetrySubmitted,
        tone: AppToastTone.success,
      );
      widget.onRetried();
    } catch (error) {
      if (!mounted) return;
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.widgetMediaImportSubmitRetryFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final matchState = ref.watch(
      importMetadataMatchProvider(widget.taskRunId, widget.item.id),
    );
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconButton(
              key: const Key('import-metadata-match-back'),
              tooltip: l10n.widgetMediaImportBackToFailedList,
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: widget.onBack,
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.widgetMediaImportManualMatchTitle,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s16,
                      weight: AppTextWeight.semibold,
                      tone: AppTextTone.primary,
                    ),
                  ),
                  SizedBox(height: spacing.xs),
                  Text(
                    widget.item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.lg),
        CatalogSearchField(
          fieldKey: const Key('import-metadata-number-field'),
          searchButtonKey: const Key('import-metadata-search-button'),
          controller: _numberController,
          hintText: l10n.widgetMediaImportNumberHint,
          searchButtonTooltip: l10n.widgetMediaImportSearchNumberTooltip,
          isSearching: matchState.isLoading,
          showSearchingIndicator: false,
          onSearchTap: matchState.isLoading ? null : _search,
          onSubmitted: (_) => _search(),
        ),
        SizedBox(height: spacing.lg),
        Expanded(child: _buildResults(context, matchState)),
        SizedBox(height: spacing.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                key: const Key('import-metadata-retry-button'),
                label: l10n.widgetMediaImportRetryWithMetadata,
                variant: AppButtonVariant.primary,
                isLoading: _isRetrying,
                onPressed: _selectedCandidateId == null || _isRetrying
                    ? null
                    : _retry,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResults(
    BuildContext context,
    ImportMetadataMatchState matchState,
  ) {
    final l10n = AppLocalizations.of(context);
    if (matchState.isLoading && matchState.response == null) {
      return const Center(child: AppInlineSpinner());
    }
    if (matchState.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              matchState.errorMessage!,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
            SizedBox(height: context.appSpacing.md),
            AppButton(
              key: const Key('import-metadata-search-retry'),
              label: l10n.commonRetry,
              onPressed: _search,
            ),
          ],
        ),
      );
    }
    final response = matchState.response;
    if (!matchState.hasSearched || response == null) {
      return Center(
        child: AppEmptyState(
          icon: Icons.search_rounded,
          message: l10n.widgetMediaImportSearchPrompt,
        ),
      );
    }
    if (response.candidates.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.search_off_rounded,
          message: l10n.widgetMediaImportNoCandidates,
        ),
      );
    }
    final sourceErrors = response.sourceErrors;
    final hasErrors = sourceErrors.isNotEmpty;
    return ListView.separated(
      itemCount: response.candidates.length + (hasErrors ? 1 : 0),
      separatorBuilder: (context, index) =>
          SizedBox(height: context.appSpacing.md),
      itemBuilder: (context, index) {
        if (hasErrors && index == 0) {
          final names = sourceErrors
              .map((error) => '「${error.sourceName}」')
              .join();
          return AppNoticeCard(
            leadingIcon: Icons.warning_amber_rounded,
            description: l10n.widgetMediaImportSourceErrors(names),
          );
        }
        final candidate = response.candidates[index - (hasErrors ? 1 : 0)];
        return _MetadataCandidateCard(
          key: Key('import-metadata-candidate-${candidate.candidateId}'),
          candidate: candidate,
          selected: candidate.candidateId == _selectedCandidateId,
          onTap: () =>
              setState(() => _selectedCandidateId = candidate.candidateId),
        );
      },
    );
  }
}

class _MetadataCandidateCard extends StatelessWidget {
  const _MetadataCandidateCard({
    super.key,
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final ImportMetadataCandidateDto candidate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appComponentTokens;
    final spacing = context.appSpacing;
    final metaParts = <String>[
      candidate.movieNumber,
      if (candidate.releaseDate case final date? when date.isNotEmpty) date,
      AppLocalizations.of(
        context,
      ).widgetMediaImportDurationMinutes(candidate.durationMinutes),
    ];
    return AppLeftCoverCard(
      coverWidth: tokens.importMetadataCandidateCoverWidth,
      // 封面为 16:9 宽图，用封面高度兜底最低行高，避免内容行数少时被压扁。
      bodyMinHeight: tokens.importMetadataCandidateCoverHeight,
      bodyPadding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.sm,
      ),
      selected: selected,
      onTap: onTap,
      cover: MaskedImage(url: candidate.coverUrl ?? '', fit: BoxFit.cover),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            candidate.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: context.appSpacing.xs),
          Text(
            metaParts.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: context.appSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppBadge(
              label: candidate.sourceName,
              tone: candidate.source == 'javdb'
                  ? AppBadgeTone.primary
                  : AppBadgeTone.neutral,
              size: AppBadgeSize.compact,
            ),
          ),
        ],
      ),
    );
  }
}
