import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/platform/clipboard_copy.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_magnet_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';

/// 可嵌入详情检查器或独立弹窗的影片磁力搜索内容。
///
/// 状态归 [movieDetailMagnetProvider]；Provider 的保活链接由承载它的页面或弹窗
/// 管理，避免共享展示组件持有跨页面生命周期。
class MovieMagnetSearchContent extends ConsumerWidget {
  static const double _sortToolbarBreakpoint = 320;

  const MovieMagnetSearchContent({super.key, required this.movieNumber});

  final String movieNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(movieDetailMagnetProvider(movieNumber));
    final controller = ref.read(
      movieDetailMagnetProvider(movieNumber).notifier,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactToolbar = constraints.maxWidth < _sortToolbarBreakpoint;
        return Padding(
          padding: EdgeInsets.only(
            top: context.appSpacing.md,
            bottom: context.appSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompactToolbar)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildSortActions(
                        context,
                        state,
                        controller,
                        compact: true,
                      ),
                    ),
                    SizedBox(height: context.appSpacing.sm),
                    _buildSearchAction(
                      context,
                      state,
                      controller,
                      alignment: Alignment.centerRight,
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSortActions(context, state, controller),
                    SizedBox(width: context.appSpacing.md),
                    Expanded(
                      child: _buildSearchAction(
                        context,
                        state,
                        controller,
                        alignment: Alignment.centerRight,
                      ),
                    ),
                  ],
                ),
              SizedBox(height: context.appSpacing.md),
              Expanded(child: _buildContent(context, state, controller)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAction(
    BuildContext context,
    MovieDetailMagnetState state,
    MovieDetailMagnet controller, {
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Align(
      alignment: alignment,
      child: AppButton(
        size: AppButtonSize.xSmall,
        key: const Key('movie-detail-magnet-search-button'),
        label: state.isLoading ? '搜索中' : '搜索资源',
        isLoading: state.isLoading,
        variant: AppButtonVariant.primary,
        onPressed: state.isLoading ? null : controller.search,
      ),
    );
  }

  Widget _buildSortActions(
    BuildContext context,
    MovieDetailMagnetState state,
    MovieDetailMagnet controller, {
    bool compact = false,
  }) {
    final nextDirectionLabel =
        state.selectedSortDirection == MovieDetailMagnetSortDirection.desc
        ? '当前降序，点击切换为升序'
        : '当前升序，点击切换为降序';
    final selectWidth = compact
        ? context.appLayoutTokens.filterFieldWidthSm - context.appSpacing.xl
        : context.appLayoutTokens.filterFieldWidthSm;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: selectWidth,
          child: AppSelectField<MovieDetailMagnetSortField>(
            key: const Key('movie-detail-magnet-sort-field'),
            value: state.selectedSortField,
            size: AppSelectFieldSize.mini,
            textStyle: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
            items: MovieDetailMagnetSortField.values
                .map(
                  (value) => DropdownMenuItem<MovieDetailMagnetSortField>(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              controller.setSortField(value);
            },
          ),
        ),
        SizedBox(width: context.appSpacing.sm),
        AppIconButton(
          key: const Key('movie-detail-magnet-sort-direction'),
          tooltip: nextDirectionLabel,
          semanticLabel: nextDirectionLabel,
          isSelected: true,
          size: AppIconButtonSize.mini,
          icon: state.selectedSortDirection.isAscending
              ? const Icon(Icons.arrow_upward_rounded)
              : const Icon(Icons.arrow_downward_rounded),
          onPressed: controller.toggleSortDirection,
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    MovieDetailMagnetState state,
    MovieDetailMagnet controller,
  ) {
    final items = state.sortedItems;

    if (state.isLoading && items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator.adaptive(
          key: Key('movie-detail-magnet-loading-indicator'),
        ),
      );
    }

    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.errorMessage!,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
            SizedBox(height: context.appSpacing.md),
            AppButton(
              key: const Key('movie-detail-magnet-retry-button'),
              label: '重试',
              variant: AppButtonVariant.secondary,
              onPressed: controller.search,
            ),
          ],
        ),
      );
    }

    if (!state.hasSearched) {
      return const Center(child: AppEmptyState(message: '搜索依赖系统设置中的下载器与索引器。'));
    }

    if (items.isEmpty) {
      return const Center(child: AppEmptyState(message: '没有找到可用资源'));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) =>
          SizedBox(height: context.appSpacing.md),
      itemBuilder: (context, index) {
        final item = items[index];
        return _MovieMagnetCandidateCard(
          key: Key('movie-detail-magnet-candidate-$index'),
          candidate: item,
          isSubmitting: state.submittingCandidateKey == item.submitKey,
          copyButtonKey: Key('movie-detail-magnet-copy-$index'),
          submitButtonKey: Key('movie-detail-magnet-submit-$index'),
          onSubmit: item.hasDownloadSource
              ? (clientId) async {
                  try {
                    final response = await controller.submitCandidate(
                      item,
                      clientId: clientId,
                    );
                    if (!context.mounted) {
                      return;
                    }
                    var selectedClientName = item.resolvedClientName;
                    for (final client in item.selectableDownloadClients) {
                      if (client.id == clientId) {
                        selectedClientName = client.name;
                        break;
                      }
                    }
                    showToast(
                      response.created ? '已提交到 $selectedClientName' : '下载任务已存在',
                    );
                  } catch (error) {
                    if (!context.mounted) {
                      return;
                    }
                    showToast(apiErrorMessage(error, fallback: '提交下载失败'));
                  }
                }
              : null,
        );
      },
    );
  }
}

class _MovieMagnetCandidateCard extends StatefulWidget {
  const _MovieMagnetCandidateCard({
    super.key,
    required this.candidate,
    required this.isSubmitting,
    required this.copyButtonKey,
    required this.submitButtonKey,
    required this.onSubmit,
  });

  final DownloadCandidateDto candidate;
  final bool isSubmitting;
  final Key copyButtonKey;
  final Key submitButtonKey;
  final ValueChanged<int>? onSubmit;

  @override
  State<_MovieMagnetCandidateCard> createState() =>
      _MovieMagnetCandidateCardState();
}

class _MovieMagnetCandidateCardState extends State<_MovieMagnetCandidateCard> {
  late int _selectedClientId;

  DownloadCandidateDto get candidate => widget.candidate;

  int get _defaultClientId {
    final clients = candidate.selectableDownloadClients;
    return clients.any((client) => client.id == candidate.resolvedClientId)
        ? candidate.resolvedClientId
        : clients.first.id;
  }

  @override
  void initState() {
    super.initState();
    _selectedClientId = _defaultClientId;
  }

  @override
  void didUpdateWidget(covariant _MovieMagnetCandidateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candidate.submitKey != candidate.submitKey ||
        !candidate.selectableDownloadClients.any(
          (client) => client.id == _selectedClientId,
        )) {
      _selectedClientId = _defaultClientId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourceUri = candidate.sourceUri.trim();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.lg),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            candidate.title,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: context.appSpacing.sm),
          Wrap(
            spacing: context.appSpacing.md,
            runSpacing: context.appSpacing.xs,
            children: [
              _MagnetMetaText(label: '索引器', value: candidate.indexerName),
              _MagnetMetaText(
                label: '类型',
                value: candidate.indexerKind.toUpperCase(),
              ),
              _MagnetMetaText(label: '做种', value: '${candidate.seeders}'),
              _MagnetMetaText(
                label: '体积',
                value: formatFileSize(candidate.sizeBytes),
              ),
            ],
          ),
          if (sourceUri.isNotEmpty) ...[
            SizedBox(height: context.appSpacing.md),
            Container(
              key: const Key('movie-detail-magnet-link'),
              width: double.infinity,
              padding: EdgeInsets.all(context.appSpacing.sm),
              decoration: BoxDecoration(
                color: context.appColors.surfaceMuted,
                borderRadius: context.appRadius.mdBorder,
                border: Border.all(color: context.appColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '资源地址',
                          style: resolveAppTextStyle(
                            context,
                            size: AppTextSize.s12,
                            weight: AppTextWeight.medium,
                            tone: AppTextTone.secondary,
                          ),
                        ),
                      ),
                      AppButton(
                        key: widget.copyButtonKey,
                        size: AppButtonSize.xxSmall,
                        label: '复制',
                        icon: const Icon(Icons.copy_rounded),
                        variant: AppButtonVariant.secondary,
                        onPressed: () async {
                          final copied = await copyTextToClipboard(sourceUri);
                          if (context.mounted) {
                            showToast(copied ? '资源地址已复制' : '复制失败，请手动选择地址');
                          }
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: context.appSpacing.xs),
                  SelectableText(
                    sourceUri,
                    key: const Key('movie-detail-magnet-link-text'),
                    maxLines: 3,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s10,
                      weight: AppTextWeight.regular,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: context.appSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppSelectField<int>(
                  key: Key('movie-detail-magnet-client-${candidate.submitKey}'),
                  value: _selectedClientId,
                  size: AppSelectFieldSize.compact,
                  items: candidate.selectableDownloadClients
                      .map(
                        (client) => DropdownMenuItem<int>(
                          value: client.id,
                          child: Text(client.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: widget.isSubmitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedClientId = value);
                          }
                        },
                ),
              ),
              SizedBox(width: context.appSpacing.md),
              AppButton(
                key: widget.submitButtonKey,
                size: AppButtonSize.xSmall,
                label: candidate.hasDownloadSource ? '提交下载' : '资源地址缺失',
                variant: AppButtonVariant.primary,
                isLoading: widget.isSubmitting,
                onPressed: widget.onSubmit == null
                    ? null
                    : () => widget.onSubmit!(_selectedClientId),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MagnetMetaText extends StatelessWidget {
  const _MagnetMetaText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.regular,
        tone: AppTextTone.secondary,
      ),
    );
  }
}
