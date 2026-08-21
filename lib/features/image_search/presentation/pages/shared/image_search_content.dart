import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_provider.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_scope.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_state.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/features/image_search/presentation/widgets/actor_selector_dialog.dart';
import 'package:sakuramedia/features/image_search/presentation/widgets/image_search_filter_panel.dart';
import 'package:sakuramedia/features/image_search/presentation/widgets/image_search_result_grid.dart';
import 'package:sakuramedia/features/image_search/presentation/widgets/image_search_result_preview_dialog.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_thumbnail.dart';

import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';

enum ImageSearchResultPreviewPresentation { dialog, bottomDrawer }

class ImageSearchContent extends ConsumerStatefulWidget {
  const ImageSearchContent({
    super.key,
    this.fallbackPath,
    this.initialFileName,
    this.initialFileBytes,
    this.initialMimeType,
    this.currentMovieNumber,
    this.initialCurrentMovieScope = ImageSearchCurrentMovieScope.all,
    this.imagePicker = pickImageSearchFile,
    this.onSearchSimilar,
    this.onOpenPlayer,
    this.onOpenMovieDetail,
    this.resultPreviewPresentation =
        ImageSearchResultPreviewPresentation.dialog,
  });

  final String? fallbackPath;
  final String? initialFileName;
  final Uint8List? initialFileBytes;
  final String? initialMimeType;
  final String? currentMovieNumber;
  final ImageSearchCurrentMovieScope initialCurrentMovieScope;
  final ImageSearchFilePicker imagePicker;
  final Future<bool> Function(
    BuildContext context,
    ImageSearchResultItemDto item,
  )?
  onSearchSimilar;
  final void Function(BuildContext context, ImageSearchResultItemDto item)?
  onOpenPlayer;
  final void Function(BuildContext context, ImageSearchResultItemDto item)?
  onOpenMovieDetail;
  final ImageSearchResultPreviewPresentation resultPreviewPresentation;

  @override
  ConsumerState<ImageSearchContent> createState() =>
      _ImageSearchContentState();
}

class _ImageSearchContentState extends ConsumerState<ImageSearchContent> {
  static const int _maxAutoLoadAttempts = 5;
  static const int _maxAutoLoadNoGrowthStreak = 2;
  static const double _loadMoreTriggerOffset = 300;

  late final ImageSearchScope _scope;
  late final RiverpodPageHandle _pageCacheHandle;
  late final ScrollController _scrollController;
  bool _isViewportFillCheckScheduled = false;
  int _autoLoadAttempts = 0;
  int _autoLoadNoGrowthStreak = 0;
  bool _autoLoadHalted = false;

  ImageSearchState get _searchState => ref.read(imageSearchProvider(_scope));
  ImageSearch get _notifier => ref.read(imageSearchProvider(_scope).notifier);
  ImageSearchFilterState get _filterState => _searchState.filterState;

  @override
  void initState() {
    super.initState();
    _scope = ImageSearchScope(_resolveStateKey());
    _scrollController = ScrollController()..addListener(_handleScroll);
    _pageCacheHandle = ref
        .read(riverpodPageCacheProvider)
        .obtain(
          key: _scope.cacheKey,
          resolveLinks: () {
            final link = _notifier.cacheLink;
            return link == null ? const [] : [link];
          },
        );
    _scheduleInitialSourceBootstrap(initialize: true);
  }

  @override
  void didUpdateWidget(covariant ImageSearchContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFileName == widget.initialFileName &&
        oldWidget.initialFileBytes == widget.initialFileBytes &&
        oldWidget.initialMimeType == widget.initialMimeType) {
      return;
    }
    _scheduleInitialSourceBootstrap();
  }

  @override
  void dispose() {
    _pageCacheHandle.release();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _scheduleInitialSourceBootstrap({bool initialize = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (initialize) {
        _notifier.initialize(widget.initialCurrentMovieScope);
      }
      _bootstrapInitialSource();
    });
  }

  void _bootstrapInitialSource() {
    final bytes = widget.initialFileBytes;
    final fileName = widget.initialFileName;
    if (bytes == null ||
        bytes.isEmpty ||
        fileName == null ||
        fileName.isEmpty) {
      return;
    }
    final signature = Object.hash(
      fileName,
      widget.initialMimeType,
      bytes.length,
    );
    if (_searchState.bootstrappedSourceSignature == signature) {
      return;
    }
    _notifier.updateFilter(
      _filterState.copyWith(currentMovieScope: widget.initialCurrentMovieScope),
    );
    _notifier.setSource(
      fileBytes: bytes,
      fileName: fileName,
      mimeType: widget.initialMimeType,
      bootstrappedSourceSignature: signature,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _runSearch();
      }
    });
  }

  Future<void> _handleTopBarRefresh() async {
    // 未选图片前刷新是没意义的（页面就一个「选择图片」空态），直接吞掉。
    if (!_searchState.hasSource) return;
    await _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final searchState = ref.watch(imageSearchProvider(_scope));
    final loadMoreFooter =
        searchState.hasSource ? _buildLoadMoreFooter(context) : null;
    ref.listen(imageSearchProvider(_scope), (_, __) {
      _scheduleViewportFillCheck();
    });

    return AppPageRefreshScope(
      onRefresh: _handleTopBarRefresh,
      child:
          !searchState.hasSource
              ? _buildInitialEmptyState(context)
              : Material(
                color: context.appColors.surfaceElevated,
                child: CustomScrollView(
                  key: PageStorageKey<String>(
                    'image-search-scroll:${_scope.cacheKey}',
                  ),
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(child: _buildSourceCard(context)),
                    if (searchState.isPreviewExpanded) ...[
                      SliverToBoxAdapter(child: SizedBox(height: spacing.lg)),
                      SliverToBoxAdapter(child: _buildPreviewPanel(context)),
                    ],
                    if (searchState.isFilterExpanded) ...[
                      SliverToBoxAdapter(child: SizedBox(height: spacing.lg)),
                      SliverToBoxAdapter(
                        child: ImageSearchFilterPanel(
                          filterState: searchState.filterState,
                          summaryText: _filterSummaryText,
                          currentMovieNumber: widget.currentMovieNumber,
                          onSearchTargetChanged:
                              (target) => _notifier.updateFilter(
                                _filterState.copyWith(searchTarget: target),
                              ),
                          onCurrentMovieScopeChanged:
                              (scope) => _notifier.updateFilter(
                                _filterState.copyWith(currentMovieScope: scope),
                              ),
                          isSearching:
                              searchState.isSearching ||
                              searchState.isResolvingActorMovieIds,
                          onModeChanged:
                              (mode) => _notifier.updateFilter(
                                _filterState.copyWith(actorFilterMode: mode),
                              ),
                          onSelectActors: _openActorSelectorDialog,
                          onSearch: _runSearch,
                        ),
                      ),
                    ],
                    SliverToBoxAdapter(child: SizedBox(height: spacing.lg)),
                    _buildResultSectionSliver(context),
                    if (loadMoreFooter != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: spacing.md),
                          child: loadMoreFooter,
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _buildInitialEmptyState(BuildContext context) {
    final spacing = context.appSpacing;

    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppEmptyState(message: '选择一张图片开始搜索'),
            SizedBox(height: spacing.lg),
            AppButton(
              key: const Key('desktop-image-search-empty-select-button'),
              label: '选择图片',
              icon: const Icon(Icons.upload_file_outlined),
              onPressed: _pickAndSearchImage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard(BuildContext context) {
    final spacing = context.appSpacing;

    return Container(
      key: const Key('desktop-image-search-source-card'),
      width: double.infinity,
      padding: EdgeInsets.all(spacing.lg),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: context.appRadius.mdBorder,
            child: SizedBox(
              key: const Key('desktop-image-search-source-thumbnail'),
              width: 170,
              child: MoviePlotThumbnail(
                imageProvider: MemoryImage(_searchState.fileBytes!),
                maxHeight: 96,
                fit: BoxFit.cover,
                borderRadius: context.appRadius.mdBorder,
              ),
            ),
          ),
          SizedBox(width: spacing.lg),
          Expanded(
            child: SizedBox(
              height: 96,
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  key: const Key('desktop-image-search-toolbar-group'),
                  spacing: spacing.sm,
                  runSpacing: spacing.sm,
                  children: [
                    AppIconButton(
                      key: const Key('desktop-image-search-change-image'),
                      tooltip: '更换图片',
                      size: AppIconButtonSize.regular,
                      iconColor: context.appTextPalette.primary,
                      icon: const Icon(Icons.image_search_outlined),
                      onPressed: _pickAndSearchImage,
                    ),
                    AppIconButton(
                      key: const Key('desktop-image-search-toggle-preview'),
                      tooltip: _searchState.isPreviewExpanded ? '收起大图' : '展示大图',
                      size: AppIconButtonSize.regular,
                      icon: Icon(
                        _searchState.isPreviewExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                      ),
                      onPressed: _notifier.togglePreviewExpanded,
                    ),
                    AppIconButton(
                      key: const Key('desktop-image-search-toggle-filter'),
                      tooltip: '高级筛选',
                      size: AppIconButtonSize.regular,
                      icon: const Icon(Icons.tune_rounded),
                      isSelected: _searchState.isFilterExpanded,
                      onPressed: _notifier.toggleFilterExpanded,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel(BuildContext context) {
    return Container(
      key: const Key('desktop-image-search-preview-panel'),
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.lg),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Center(
        child: MoviePlotThumbnail(
          imageProvider: MemoryImage(_searchState.fileBytes!),
          maxHeight: 320,
          fit: BoxFit.contain,
          borderRadius: context.appRadius.mdBorder,
        ),
      ),
    );
  }

  Widget _buildResultSectionSliver(BuildContext context) {
    final searchState = _searchState;
    if (searchState.isSearching && searchState.items.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.appLayoutTokens.emptySectionVerticalPadding,
            ),
            child: CircularProgressIndicator(
              key: Key('desktop-image-search-loading-indicator'),
            ),
          ),
        ),
      );
    }

    if (searchState.errorMessage != null && searchState.items.isEmpty) {
      return SliverToBoxAdapter(
        child: AppEmptyState(message: searchState.errorMessage!),
      );
    }

    if (searchState.items.isEmpty) {
      return const SliverToBoxAdapter(child: AppEmptyState(message: '暂无匹配结果'));
    }

    return ImageSearchResultSliver(
      items: searchState.items,
      onItemTap: _openResultPreviewDialog,
      onItemMenuRequested: _showResultActions,
    );
  }

  Widget? _buildLoadMoreFooter(BuildContext context) {
    final searchState = _searchState;
    if (searchState.items.isEmpty) {
      return null;
    }

    final spacing = context.appSpacing;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;

    if (searchState.isLoadingMore) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.md),
          child: SizedBox(
            width: componentTokens.movieCardLoaderSize,
            height: componentTokens.movieCardLoaderSize,
            child: CircularProgressIndicator(
              strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
            ),
          ),
        ),
      );
    }

    if (!_hasLoadMoreError) {
      return null;
    }

    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: context.appRadius.mdBorder,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: componentTokens.iconSizeXl,
                color: context.appTextPalette.secondary,
              ),
              SizedBox(width: spacing.sm),
              Text(
                searchState.errorMessage!,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(width: spacing.sm),
              TextButton(
                onPressed: _notifier.loadMore,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.sm,
                    vertical: spacing.xs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _filterSummaryText {
    final normalizedMovieNumber = widget.currentMovieNumber?.trim();
    final currentMovieText =
        normalizedMovieNumber == null || normalizedMovieNumber.isEmpty
            ? null
            : '当前影片：${_filterState.currentMovieScope.label}';
    final actorText =
        _filterState.actorFilterMode == ImageSearchActorFilterMode.none
            ? '女优：不过滤'
            : '女优：${_filterState.actorFilterMode.label}（已选 ${_filterState.selectedActorCount} 位）';
    return currentMovieText == null
        ? actorText
        : '$currentMovieText · $actorText';
  }

  Future<void> _runSearch() {
    _resetAutoLoadState();
    return _notifier.search(
      filter: _filterState,
      currentMovieNumber: widget.currentMovieNumber,
    );
  }

  void _resetAutoLoadState() {
    _autoLoadAttempts = 0;
    _autoLoadNoGrowthStreak = 0;
    _autoLoadHalted = false;
  }

  bool get _hasLoadMoreError =>
      _searchState.errorMessage == '加载更多失败，请稍后重试' &&
      _searchState.items.isNotEmpty;

  void _handleScroll() {
    final searchState = _searchState;
    if (!_scrollController.hasClients ||
        searchState.isSearching ||
        searchState.isLoadingMore ||
        searchState.errorMessage != null ||
        !searchState.hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreTriggerOffset) {
      unawaited(_notifier.loadMore());
    }
  }

  void _scheduleViewportFillCheck() {
    if (_isViewportFillCheckScheduled || !mounted) {
      return;
    }
    _isViewportFillCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isViewportFillCheckScheduled = false;
      if (!mounted || !_shouldAutoLoadMoreForViewport()) {
        return;
      }
      _autoLoadMoreForViewport();
    });
  }

  String _resolveStateKey() {
    final routeLocation = _currentRouteLocation();
    if (routeLocation != null && routeLocation.startsWith('/mobile/')) {
      return mobileImageSearchPageCacheKey(routeLocation);
    }
    if ((widget.fallbackPath ?? '').startsWith('/mobile/')) {
      return mobileImageSearchPageCacheKey(widget.fallbackPath!);
    }
    return desktopImageSearchPageCacheKey(
      routeLocation ?? widget.fallbackPath ?? desktopImageSearchPath,
    );
  }

  String? _currentRouteLocation() {
    try {
      return GoRouterState.of(context).uri.toString();
    } catch (_) {
      return null;
    }
  }

  bool _shouldAutoLoadMoreForViewport() {
    final searchState = _searchState;
    if (!searchState.hasMore ||
        searchState.isSearching ||
        searchState.isLoadingMore ||
        _autoLoadHalted ||
        _autoLoadAttempts >= _maxAutoLoadAttempts ||
        _hasLoadMoreError ||
        !_scrollController.hasClients) {
      return false;
    }
    if (searchState.items.isEmpty) {
      final currentMovieNumber = widget.currentMovieNumber?.trim();
      return _filterState.currentMovieScope !=
              ImageSearchCurrentMovieScope.all &&
          currentMovieNumber != null &&
          currentMovieNumber.isNotEmpty;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) {
      return true;
    }
    if (position.pixels <= 0) {
      return false;
    }
    return position.pixels >= position.maxScrollExtent - _loadMoreTriggerOffset;
  }

  void _autoLoadMoreForViewport() {
    final baselineItemCount = _searchState.items.length;
    _autoLoadAttempts += 1;
    unawaited(
      _notifier.loadMore().whenComplete(() {
        if (!mounted) {
          return;
        }
        final hasVisibleGrowth = _searchState.items.length > baselineItemCount;
        if (hasVisibleGrowth) {
          _autoLoadNoGrowthStreak = 0;
        } else {
          _autoLoadNoGrowthStreak += 1;
        }
        if (_autoLoadAttempts >= _maxAutoLoadAttempts ||
            _autoLoadNoGrowthStreak >= _maxAutoLoadNoGrowthStreak) {
          _autoLoadHalted = true;
        }
        _scheduleViewportFillCheck();
      }),
    );
  }

  Future<void> _openActorSelectorDialog() async {
    await _notifier.ensureSubscribedActorsLoaded();
    if (!mounted || _searchState.subscribedActorsErrorMessage != null) {
      return;
    }
    final selectedActors = await showActorSelectorOverlay(
      context,
      actors: _searchState.subscribedActors,
      initialSelectedActors: _filterState.selectedActors,
    );
    if (!mounted || selectedActors == null) {
      return;
    }
    _notifier.updateFilter(
      _filterState.copyWith(selectedActors: selectedActors),
    );
  }

  Future<void> _pickAndSearchImage() async {
    try {
      final pickedFile = await widget.imagePicker();
      if (pickedFile == null || !mounted) {
        return;
      }
      _notifier.setSource(
        fileBytes: pickedFile.bytes,
        fileName: pickedFile.fileName,
        mimeType: pickedFile.mimeType,
      );
      await _runSearch();
    } on ImageSearchFilePickerException catch (error) {
      if (mounted) {
        showToast(error.message);
      }
    } catch (_) {
      if (mounted) {
        showToast('选择图片失败');
      }
    }
  }

  Future<void> _openResultPreviewDialog(ImageSearchResultItemDto item) async {
    final presentation =
        widget.resultPreviewPresentation ==
                ImageSearchResultPreviewPresentation.bottomDrawer
            ? MediaPreviewPresentation.bottomDrawer
            : MediaPreviewPresentation.dialog;
    final action = await showMediaPreviewOverlay(
      context: context,
      presentation: presentation,
      drawerKey:
          presentation == MediaPreviewPresentation.bottomDrawer
              ? const Key('image-search-result-preview-bottom-sheet')
              : null,
      builder:
          (_) => ImageSearchResultPreviewDialog(
            item: item,
            presentation: presentation,
          ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case MediaPreviewAction.searchSimilar:
        await _searchSimilarFromResult(item);
      case MediaPreviewAction.play:
        _openPlayerForResult(item);
      case MediaPreviewAction.openMovieDetail:
        _openMovieDetailForResult(item);
    }
  }

  Future<bool> _searchSimilarFromResult(ImageSearchResultItemDto item) async {
    final customHandler = widget.onSearchSimilar;
    if (customHandler != null) {
      return customHandler(context, item);
    }
    try {
      await launchDesktopImageSearchFromUrl(
        context,
        imageUrl: _resultImageUrl(item),
        fallbackPath: widget.fallbackPath ?? desktopOverviewPath,
        fileName: _resultImageFileName(item),
      );
      return true;
    } catch (_) {
      if (mounted) {
        showToast('读取结果图片失败，请稍后重试');
      }
      return false;
    }
  }

  void _openPlayerForResult(ImageSearchResultItemDto item) {
    final customHandler = widget.onOpenPlayer;
    if (customHandler != null) {
      customHandler(context, item);
      return;
    }
    context.pushDesktopMoviePlayer(
      movieNumber: item.movieNumber,
      fallbackPath: desktopImageSearchPath,
      mediaId: item.mediaId > 0 ? item.mediaId : null,
      positionSeconds: item.offsetSeconds,
    );
  }

  void _openMovieDetailForResult(ImageSearchResultItemDto item) {
    final customHandler = widget.onOpenMovieDetail;
    if (customHandler != null) {
      customHandler(context, item);
      return;
    }
    context.pushDesktopMovieDetail(
      movieNumber: item.movieNumber,
      fallbackPath: desktopImageSearchPath,
    );
  }

  String _resultImageUrl(ImageSearchResultItemDto item) {
    final origin = item.image.origin.trim();
    if (origin.isNotEmpty) {
      return origin;
    }
    return item.image.bestAvailableUrl;
  }

  String _resultImageFileName(ImageSearchResultItemDto item) {
    final extension = guessImageFileExtension(_resultImageUrl(item));
    return 'image_search_${item.movieNumber}_${item.resultImageId}.$extension';
  }

  Future<void> _showResultActions(
    ImageSearchResultItemDto item,
    Offset globalPosition,
  ) async {
    final point = await _loadMatchingPoint(item);
    if (!mounted) {
      return;
    }
    final action = await showAppImageActionMenu(
      context: context,
      actions: _buildResultActionDescriptors(item, point),
      globalPosition: globalPosition,
      presentation: AppImageActionMenuPresentation.auto,
    );
    if (!mounted || action == null) {
      return;
    }
    await _handleResultAction(item, action, point);
  }

  List<AppImageActionDescriptor> _buildResultActionDescriptors(
    ImageSearchResultItemDto item,
    MediaPointDto? point,
  ) {
    final hasMedia = item.mediaId > 0;
    return <AppImageActionDescriptor>[
      const AppImageActionDescriptor(
        type: AppImageActionType.searchSimilar,
        label: '相似图片',
        icon: Icons.image_search_outlined,
      ),
      const AppImageActionDescriptor(
        type: AppImageActionType.saveToLocal,
        label: '保存到本地',
        icon: Icons.download_outlined,
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.toggleMark,
        label: point == null ? '添加标记' : '删除标记',
        icon:
            point == null
                ? Icons.bookmark_add_outlined
                : Icons.bookmark_remove_outlined,
        enabled: hasMedia,
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.play,
        label: '播放',
        icon: Icons.play_circle_outline_rounded,
        enabled: hasMedia,
      ),
      const AppImageActionDescriptor(
        type: AppImageActionType.movieDetail,
        label: '影片详情',
        icon: Icons.info_outline_rounded,
      ),
    ];
  }

  Future<void> _handleResultAction(
    ImageSearchResultItemDto item,
    AppImageActionType action,
    MediaPointDto? point,
  ) async {
    switch (action) {
      case AppImageActionType.searchSimilar:
        await _searchSimilarFromResult(item);
        break;
      case AppImageActionType.saveToLocal:
        await _saveResultImageToLocal(item);
        break;
      case AppImageActionType.toggleMark:
        await _toggleResultPoint(item, point);
        break;
      case AppImageActionType.play:
        _openPlayerForResult(item);
        break;
      case AppImageActionType.movieDetail:
        _openMovieDetailForResult(item);
        break;
    }
  }

  Future<MediaPointDto?> _loadMatchingPoint(
    ImageSearchResultItemDto item,
  ) async {
    if (item.mediaId <= 0 || item.thumbnailId <= 0) {
      return null;
    }
    final points = await ref
        .read(mediaApiProvider)
        .getMediaPoints(mediaId: item.mediaId);
    for (final point in points) {
      if (point.thumbnailId == item.thumbnailId) {
        return point;
      }
    }
    return null;
  }

  Future<void> _saveResultImageToLocal(ImageSearchResultItemDto item) async {
    final result = await ImageSaveService(
      fetchBytes: ref.read(apiClientProvider).getBytes,
    ).saveImageFromUrl(
      imageUrl: _resultImageUrl(item),
      fileName: _resultImageFileName(item),
      dialogTitle: '保存到本地',
    );
    if (!mounted) {
      return;
    }
    if (result.status == ImageSaveStatus.success) {
      showToast(result.message ?? '图片已保存');
    }
    if (result.status == ImageSaveStatus.failed) {
      showToast(result.message ?? '保存失败，请稍后重试');
    }
  }

  Future<void> _toggleResultPoint(
    ImageSearchResultItemDto item,
    MediaPointDto? point,
  ) async {
    if (item.mediaId <= 0 || item.thumbnailId <= 0) {
      return;
    }
    try {
      if (point == null) {
        await ref
            .read(mediaApiProvider)
            .createMediaPoint(
              mediaId: item.mediaId,
              thumbnailId: item.thumbnailId,
            );
        if (mounted) {
          showToast('已添加标记');
        }
        return;
      }
      await ref
          .read(mediaApiProvider)
          .deleteMediaPoint(mediaId: item.mediaId, pointId: point.pointId);
      if (mounted) {
        showToast('已删除标记');
      }
    } catch (_) {
      if (mounted) {
        showToast('更新标记失败');
      }
    }
  }
}
