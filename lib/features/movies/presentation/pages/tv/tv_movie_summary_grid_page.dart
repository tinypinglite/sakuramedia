import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_state.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_update_bar.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_popover.dart';
import 'package:sakuramedia/widgets/base/tv/tv_card_grid.dart';
import 'package:sakuramedia/widgets/base/tv/tv_movie_card.dart';
import 'package:sakuramedia/widgets/base/tv/tv_page.dart';

/// 电视端影片网格页：影片库、女优作品与播放列表详情共用。
///
/// 页头、排序入口和网格在同一个滚动视图里，滚动后一起离开视口，避免两排
/// 排序长期占用电视可用高度。排序入口只保留当前选项，点开后复用桌面弹层里
/// 的 [AppGlassSortSection] 选择字段与方向。
class TvMovieSummaryGridPage extends ConsumerStatefulWidget {
  const TvMovieSummaryGridPage({
    super.key,
    required this.scope,
    required this.title,
    required this.pageKey,
    this.playlistDefaultSortLabel,
  });

  final MovieSummaryScope scope;
  final String title;
  final Key pageKey;

  /// 播放列表「默认」排序的展示文案；智能列表传保存排序（如「发布时间 ↓」），
  /// 普通列表不传，回退到「最近触达」。
  final String? playlistDefaultSortLabel;

  @override
  ConsumerState<TvMovieSummaryGridPage> createState() =>
      _TvMovieSummaryGridPageState();
}

class _TvMovieSummaryGridPageState
    extends ConsumerState<TvMovieSummaryGridPage> {
  final ScrollController _scrollController = ScrollController();

  bool get _supportsSort => switch (widget.scope.source) {
    MovieSummarySource.movies ||
    MovieSummarySource.actor ||
    MovieSummarySource.playlist => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter > 900) {
      return;
    }
    final state = ref.read(movieSummaryProvider(widget.scope)).value;
    if (state?.paged.canAutoLoadMore ?? false) {
      unawaited(
        ref.read(movieSummaryProvider(widget.scope).notifier).loadMore(),
      );
    }
  }

  /// 重排后旧列表仍保留到新结果返回；先回顶，避免用户停在错位的位置。
  void _scrollToStart() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.minScrollExtent);
    }
  }

  void _applyMovieSort(MovieFilterState next) {
    final provider = movieSummaryProvider(widget.scope);
    final current = ref.read(provider).value?.filter.movie;
    if (current != null && next.matches(current)) {
      return;
    }
    _scrollToStart();
    unawaited(ref.read(provider.notifier).applyMovieFilter(next));
  }

  void _applyPlaylistSort(PlaylistFilterState next) {
    final provider = movieSummaryProvider(widget.scope);
    final current = ref.read(provider).value?.filter.playlist;
    if (current != null && next.matches(current)) {
      return;
    }
    _scrollToStart();
    unawaited(ref.read(provider.notifier).applyPlaylistFilter(next));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(movieSummaryProvider(widget.scope));
    final state = async.value;
    final items = state?.paged.items ?? const <MovieListItemDto>[];
    final filterUpdate = state?.paged.filterUpdate;
    final supportsSort = _supportsSort;
    final statsEnabled = supportsSort
        ? ref.watch(statsFeaturesEnabledProvider)
        : false;
    final sortTrigger = state == null || !supportsSort
        ? null
        : _buildSortTrigger(state, l10n, statsEnabled);

    return KeyedSubtree(
      key: widget.pageKey,
      child: TvPagePadding(
        child: AppFilterResultLoadingOverlay(
          isLoading: (filterUpdate?.isLoading ?? false) && !async.isLoading,
          hasPreviousItems: items.isNotEmpty,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TvPageHeader(
                      title: widget.title,
                      subtitle: state == null
                          ? null
                          : l10n.moviePageMovieCount(state.paged.total),
                      trailing: sortTrigger,
                    ),
                    if (filterUpdate != null && filterUpdate.hasFailed) ...[
                      SizedBox(height: context.appSpacing.sm),
                      AppFilterUpdateBar(
                        state: filterUpdate,
                        hasPreviousItems: items.isNotEmpty,
                        onRetry: () => unawaited(
                          ref
                              .read(movieSummaryProvider(widget.scope).notifier)
                              .retryFilter(),
                        ),
                      ),
                    ],
                    SizedBox(height: context.appSpacing.xl),
                  ],
                ),
              ),
              ..._buildContentSlivers(context, async, items, l10n),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContentSlivers(
    BuildContext context,
    AsyncValue<MovieSummaryState> async,
    List<MovieListItemDto> items,
    AppLocalizations l10n,
  ) {
    if (async.isLoading && items.isEmpty) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (async.hasError && items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppErrorState(
            title: l10n.baseActionFailed,
            message: l10n.errorMovieListLoadFailed,
            onRetry: () => ref.invalidate(movieSummaryProvider(widget.scope)),
          ),
        ),
      ];
    }
    if (items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(message: l10n.widgetMovieEmptyList),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: EdgeInsets.only(bottom: context.appSpacing.xxxl),
        sliver: TvCardSliverGrid<MovieListItemDto>(
          gridKey: const Key('tv-movie-grid'),
          items: items,
          itemBuilder: (context, movie) => TvMovieCard(
            movie: movie,
            onPressed: () => TvRoutes.movieDetail(
              movieNumber: movie.movieNumber,
            ).push(context),
          ),
        ),
      ),
    ];
  }

  Widget _buildSortTrigger(
    MovieSummaryState state,
    AppLocalizations l10n,
    bool statsEnabled,
  ) {
    final isPlaylist = widget.scope.source == MovieSummarySource.playlist;
    final summary = isPlaylist
        ? _playlistSortSummary(state, l10n, statsEnabled)
        : _movieSortSummary(state, l10n, statsEnabled);
    return AppButton(
      key: const Key('tv-sort-trigger'),
      label: l10n.tvSortEntryLabel(summary),
      icon: const Icon(Icons.swap_vert_rounded),
      size: AppButtonSize.tvLarge,
      variant: AppButtonVariant.tonal,
      borderRadius: context.appRadius.pillBorder,
      onPressed: () => unawaited(
        isPlaylist
            ? _openPlaylistSortDialog(state, l10n, statsEnabled)
            : _openMovieSortDialog(state, l10n, statsEnabled),
      ),
    );
  }

  String _movieSortSummary(
    MovieSummaryState state,
    AppLocalizations l10n,
    bool statsEnabled,
  ) {
    final filter = state.filter.movie;
    final field = visibleMovieSortField(
      filter.sortField,
      statsEnabled: statsEnabled,
    );
    return '${field.labelWith(l10n)} ${filter.sortDirection.symbol}';
  }

  String _playlistSortSummary(
    MovieSummaryState state,
    AppLocalizations l10n,
    bool statsEnabled,
  ) {
    final filter = statsEnabled
        ? state.filter.playlist
        : state.filter.playlist.withoutStatsFeatures();
    final field = filter.sortField;
    if (field == null) {
      return widget.playlistDefaultSortLabel ?? l10n.playlistSortDefault;
    }
    return '${field.label(l10n)} ${filter.sortDirection.symbol}';
  }

  Future<void> _openMovieSortDialog(
    MovieSummaryState state,
    AppLocalizations l10n,
    bool statsEnabled,
  ) async {
    final filter = state.filter.movie;
    final selection = await _showSortDialog<MovieSortField>(
      fields: visibleMovieSortFields(statsEnabled: statsEnabled),
      initialField: visibleMovieSortField(
        filter.sortField,
        statsEnabled: statsEnabled,
      ),
      initialDirection: filter.sortDirection,
      fieldLabelBuilder: (field) => field.labelWith(l10n),
      fieldKeyBuilder: (field) => Key('tv-sort-field-${field.name}'),
      directionKeyBuilder: (direction) =>
          Key('tv-sort-direction-${direction.name}'),
    );
    if (selection == null || !mounted) {
      return;
    }
    final field = selection.field;
    if (field == null) {
      return;
    }
    _applyMovieSort(
      filter.copyWith(
        sortField: field,
        sortDirection: selection.direction,
        dimensionSortId: null,
      ),
    );
  }

  Future<void> _openPlaylistSortDialog(
    MovieSummaryState state,
    AppLocalizations l10n,
    bool statsEnabled,
  ) async {
    final filter = statsEnabled
        ? state.filter.playlist
        : state.filter.playlist.withoutStatsFeatures();
    final selection = await _showSortDialog<PlaylistSortField>(
      fields: visiblePlaylistSortFields(statsEnabled: statsEnabled),
      initialField: filter.sortField,
      initialDirection: filter.sortDirection,
      fieldLabelBuilder: (field) => field.label(l10n),
      allowDefaultOption: true,
      defaultOptionLabel:
          widget.playlistDefaultSortLabel ?? l10n.playlistSortDefault,
      directionVisibleWhen: (field) => field != null,
      fieldKeyBuilder: (field) => Key('tv-sort-field-${field.name}'),
      directionKeyBuilder: (direction) =>
          Key('tv-sort-direction-${direction.name}'),
      defaultOptionKey: const Key('tv-sort-default'),
    );
    if (selection == null || !mounted) {
      return;
    }
    _applyPlaylistSort(
      filter.copyWith(
        sortField: selection.field,
        sortDirection: selection.direction,
      ),
    );
  }

  Future<_TvSortSelection<F>?> _showSortDialog<F>({
    required List<F> fields,
    required F? initialField,
    required SortDirection initialDirection,
    required String Function(F field) fieldLabelBuilder,
    bool allowDefaultOption = false,
    String? defaultOptionLabel,
    bool Function(F? field)? directionVisibleWhen,
    Key? Function(F field)? fieldKeyBuilder,
    Key? Function(SortDirection direction)? directionKeyBuilder,
    Key? defaultOptionKey,
  }) {
    return showAppAdaptiveModal<_TvSortSelection<F>>(
      context: context,
      variant: AppAdaptiveModalVariant.dialog,
      dialogKey: const Key('tv-sort-dialog'),
      desktopWidth: AppTvTokens.sortDialogWidth,
      desktopBackgroundColor: context.appColors.surfaceElevated,
      showDesktopCloseButton: false,
      builder: (modalContext) => _TvSortDialog<F>(
        fields: fields,
        initialField: initialField,
        initialDirection: initialDirection,
        fieldLabelBuilder: fieldLabelBuilder,
        allowDefaultOption: allowDefaultOption,
        defaultOptionLabel: defaultOptionLabel,
        directionVisibleWhen: directionVisibleWhen,
        fieldKeyBuilder: fieldKeyBuilder,
        directionKeyBuilder: directionKeyBuilder,
        defaultOptionKey: defaultOptionKey,
      ),
    );
  }
}

typedef _TvSortSelection<F> = ({F? field, SortDirection direction});

class _TvSortDialog<F> extends StatefulWidget {
  const _TvSortDialog({
    required this.fields,
    required this.initialField,
    required this.initialDirection,
    required this.fieldLabelBuilder,
    required this.allowDefaultOption,
    required this.defaultOptionLabel,
    required this.directionVisibleWhen,
    required this.fieldKeyBuilder,
    required this.directionKeyBuilder,
    required this.defaultOptionKey,
  });

  final List<F> fields;
  final F? initialField;
  final SortDirection initialDirection;
  final String Function(F field) fieldLabelBuilder;
  final bool allowDefaultOption;
  final String? defaultOptionLabel;
  final bool Function(F? field)? directionVisibleWhen;
  final Key? Function(F field)? fieldKeyBuilder;
  final Key? Function(SortDirection direction)? directionKeyBuilder;
  final Key? defaultOptionKey;

  @override
  State<_TvSortDialog<F>> createState() => _TvSortDialogState<F>();
}

class _TvSortDialogState<F> extends State<_TvSortDialog<F>> {
  late F? _field = widget.initialField;
  late SortDirection _direction = widget.initialDirection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.baseSortTooltip,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s24,
            weight: AppTextWeight.semibold,
          ),
        ),
        SizedBox(height: spacing.lg),
        AppGlassSortSection<F>(
          fields: widget.fields,
          selectedField: _field,
          fieldLabelBuilder: widget.fieldLabelBuilder,
          onFieldChanged: (field) => setState(() => _field = field),
          selectedDirection: _direction,
          onDirectionChanged: (direction) =>
              setState(() => _direction = direction),
          directionVisibleWhen: widget.directionVisibleWhen,
          allowDefaultOption: widget.allowDefaultOption,
          defaultOptionLabel: widget.defaultOptionLabel,
          fieldKeyBuilder: widget.fieldKeyBuilder,
          directionKeyBuilder: widget.directionKeyBuilder,
          defaultOptionKey: widget.defaultOptionKey,
          segmentedSize: AppSegmentedSize.large,
        ),
        SizedBox(height: spacing.xl),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(
            key: const Key('tv-sort-apply'),
            label: l10n.commonDone,
            size: AppButtonSize.tvLarge,
            variant: AppButtonVariant.primary,
            onPressed: () => Navigator.of(
              context,
            ).pop((field: _field, direction: _direction)),
          ),
        ),
      ],
    );
  }
}
