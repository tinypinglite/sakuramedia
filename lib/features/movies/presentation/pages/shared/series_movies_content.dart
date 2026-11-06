import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_summary_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/series_import/series_import_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';

typedef SeriesMoviesBodyBuilder =
    Widget Function(
      BuildContext context,
      ScrollController scrollController,
      Widget sliver,
      Future<void> Function()? onRefresh,
    );

/// 系列影片列表：在通用影片列表壳上补系列名、导入与标题上报。
class SeriesMoviesContent extends ConsumerStatefulWidget {
  const SeriesMoviesContent({
    super.key,
    required this.seriesId,
    required this.contentKey,
    required this.totalKey,
    required this.sectionSpacing,
    required this.onMovieTap,
    required this.bodyBuilder,
    this.initialSeriesName,
    this.enableRefresh = false,
    this.onRefreshFailure,
    this.useMobileSelectionLayout = false,
    this.hoistTitleToSubpageShell = false,
  });

  final int seriesId;
  final String? initialSeriesName;
  final Key contentKey;
  final Key totalKey;
  final double sectionSpacing;
  final void Function(BuildContext context, String movieNumber) onMovieTap;
  final SeriesMoviesBodyBuilder bodyBuilder;
  final bool enableRefresh;
  final void Function(BuildContext context)? onRefreshFailure;

  /// 移动端多选入口挂卡片长按，批量动作走底部条；桌面批量动作内联在顶栏。
  final bool useMobileSelectionLayout;

  /// 把系列名报给外层移动子页壳返回栏；桌面仍留在页内信息槽。
  final bool hoistTitleToSubpageShell;

  @override
  ConsumerState<SeriesMoviesContent> createState() =>
      _SeriesMoviesContentState();
}

class _SeriesMoviesContentState extends ConsumerState<SeriesMoviesContent> {
  late final String? _initialSeriesName;

  MovieSummaryScope get _scope =>
      MovieSummaryScope.series(seriesId: widget.seriesId);

  @override
  void initState() {
    super.initState();
    _initialSeriesName = _normalizeSeriesName(widget.initialSeriesName);
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(
      movieSummaryProvider(_scope).select(
        (async) => async.value?.paged.items ?? const <MovieListItemDto>[],
      ),
    );
    if (widget.hoistTitleToSubpageShell) {
      _reportTitleToShell(items);
    }
    return MovieSummaryListContent(
      scope: _scope,
      surfaceColor: context.appColors.surfaceElevated,
      contentKey: widget.contentKey,
      totalKey: widget.totalKey,
      sectionSpacing: widget.sectionSpacing,
      batchKeyPrefix: 'series-movies',
      onMovieTap: widget.onMovieTap,
      bodyBuilder: widget.bodyBuilder,
      enableRefresh: widget.enableRefresh,
      registerPageRefresh: true,
      onRefreshFailure: widget.onRefreshFailure,
      onInitialErrorRetry: () =>
          ref.read(movieSummaryProvider(_scope).notifier).reload(),
      useMobileSelectionLayout: widget.useMobileSelectionLayout,
      headerBuilder: (context, args) => _buildHeader(context, items, args),
    );
  }

  /// 系列页没有筛选维度：左侧是系列名/总数，右侧是导入与选择。
  Widget _buildHeader(
    BuildContext context,
    Iterable<MovieListItemDto> movies,
    MovieSummaryListHeaderArgs args,
  ) {
    final l10n = AppLocalizations.of(context);
    final seriesName = _displaySeriesName(movies, l10n: l10n);
    final totalLabel = l10n.moviePageSeriesTotalCount(args.total);
    if (!widget.useMobileSelectionLayout) {
      return AppGlassListHeader(
        leading: AppGlassHeaderGroup(
          children: <Widget>[
            if (!widget.hoistTitleToSubpageShell)
              AppGlassHeaderText(
                key: const Key('series-movies-title'),
                label: seriesName,
              ),
            AppGlassHeaderText(key: widget.totalKey, label: totalLabel),
          ],
        ),
        trailing: AppGlassHeaderGroup(
          children: <Widget>[
            AppGlassHeaderButton(
              key: const Key('series-movies-import-button'),
              icon: Icons.sync_rounded,
              label: l10n.moviePageSeriesSync,
              onTap: _handleImport,
            ),
            AppGlassHeaderButton(
              key: const Key('series-movies-enter-selection-button'),
              icon: Icons.check_circle_outline,
              label: l10n.baseSelect,
              enabled: args.onEnterSelection != null,
              onTap: args.onEnterSelection ?? () {},
            ),
          ],
        ),
        filterUpdate: args.filterUpdate,
        hasPreviousFilterItems: args.total > 0,
        onRetryFilter: args.onRetryFilter,
      );
    }
    return AppMobileListHeader(
      leading: AppMobileHeaderText(
        key: widget.totalKey,
        title: widget.hoistTitleToSubpageShell ? null : seriesName,
        countLabel: totalLabel,
      ),
      actions: <Widget>[
        AppGlassIconButton(
          key: const Key('series-movies-import-button'),
          tooltip: l10n.moviePageSeriesSync,
          icon: Icons.sync_rounded,
          onPressed: _handleImport,
        ),
      ],
      filterUpdate: args.filterUpdate,
      hasPreviousFilterItems: args.total > 0,
      onRetryFilter: args.onRetryFilter,
    );
  }

  Future<void> _handleImport() async {
    final hasNewMovies = await showSeriesImportDialog(context, widget.seriesId);
    if (hasNewMovies && mounted) {
      await ref.read(movieSummaryProvider(_scope).notifier).refresh();
    }
  }

  String _displaySeriesName(
    Iterable<MovieListItemDto> movies, {
    required AppLocalizations l10n,
  }) {
    final initialSeriesName = _initialSeriesName;
    if (initialSeriesName != null) return initialSeriesName;
    for (final movie in movies) {
      final seriesName = movie.seriesName.trim();
      if (seriesName.isNotEmpty) return seriesName;
    }
    return l10n.moviePageSeriesFallbackName(widget.seriesId);
  }

  /// 数据异步到达，用 post-frame 回调写返回栏，避免 build 期间改 notifier。
  void _reportTitleToShell(Iterable<MovieListItemDto> movies) {
    final name = _displaySeriesName(
      movies,
      l10n: AppLocalizations.of(context),
    ).trim();
    if (name.isEmpty) {
      return;
    }
    final notifier = AppMobileSubpageTitle.read(context);
    if (notifier == null || notifier.value == name) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        notifier.value = name;
      }
    });
  }
}

String? _normalizeSeriesName(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
