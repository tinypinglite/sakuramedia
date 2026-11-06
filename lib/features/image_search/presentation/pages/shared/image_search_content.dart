import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/media/image_save_service.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/features/image_search/presentation/actions/image_search_launcher.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_file_picker.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_provider.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_scope.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_state.dart';
import 'package:sakuramedia/features/media/data/media_point_dto.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_playback_launcher.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';
import 'package:sakuramedia/features/image_search/presentation/widgets/actor_selector_dialog.dart';
import 'package:sakuramedia/features/image_search/presentation/widgets/image_search_filter_panel.dart';
import 'package:sakuramedia/features/image_search/presentation/widgets/image_search_result_grid.dart';
import 'package:sakuramedia/features/image_search/presentation/widgets/image_search_result_preview_dialog.dart';
import 'package:sakuramedia/features/moment_collections/presentation/widgets/add_to_moment_collection_dialog.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_bottom_safe_area_sliver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_scope.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_menu.dart';
import 'package:sakuramedia/widgets/base/overlays/app_action_menu.dart';
import 'package:sakuramedia/widgets/domain/media/preview/media_preview_dialog.dart';
import 'package:sakuramedia/widgets/domain/search/catalog_search_field.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_thumbnail.dart';
import 'package:sakuramedia/features/status/presentation/providers/server_capabilities_provider.dart';

import 'package:sakuramedia/features/media/presentation/providers/media_api_provider.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

enum ImageSearchResultPreviewPresentation { dialog, bottomDrawer }

Future<ImageSearchPickedFile?> _defaultImageSearchFilePicker(
  AppLocalizations l10n,
) {
  return pickImageSearchFile(l10n: l10n);
}

class ImageSearchContent extends ConsumerStatefulWidget {
  const ImageSearchContent({
    super.key,
    required this.surfaceColor,
    this.fallbackPath,
    this.initialFileName,
    this.initialFileBytes,
    this.initialMimeType,
    this.currentMovieNumber,
    this.initialCurrentMovieScope = ImageSearchCurrentMovieScope.all,
    this.initialInputKind = ImageSearchInputKind.image,
    this.imagePicker = _defaultImageSearchFilePicker,
    this.onSearchSimilar,
    this.onOpenPlayer,
    this.onOpenMovieDetail,
    this.onOpenActorDetail,
    this.resultPreviewPresentation =
        ImageSearchResultPreviewPresentation.dialog,
  });

  final Color surfaceColor;
  final String? fallbackPath;
  final String? initialFileName;
  final Uint8List? initialFileBytes;
  final String? initialMimeType;
  final String? currentMovieNumber;
  final ImageSearchCurrentMovieScope initialCurrentMovieScope;
  final ImageSearchInputKind initialInputKind;
  final LocalizedImageSearchFilePicker imagePicker;
  final Future<bool> Function(
    BuildContext context,
    ImageSearchResultItemDto item,
  )?
  onSearchSimilar;
  final void Function(BuildContext context, ImageSearchResultItemDto item)?
  onOpenPlayer;
  final void Function(BuildContext context, ImageSearchResultItemDto item)?
  onOpenMovieDetail;
  final void Function(BuildContext context, int actorId)? onOpenActorDetail;
  final ImageSearchResultPreviewPresentation resultPreviewPresentation;

  @override
  ConsumerState<ImageSearchContent> createState() => _ImageSearchContentState();
}

class _ImageSearchContentState extends ConsumerState<ImageSearchContent> {
  static const int _maxAutoLoadNoGrowthStreak = 2;

  late final ImageSearchScope _scope;
  late final RiverpodPageHandle _pageCacheHandle;
  late final ScrollController _scrollController;
  late final TextEditingController _textController;
  ImageSearchFilterState? _desktopFilterDraft;
  int _autoLoadNoGrowthStreak = 0;
  bool _autoLoadHalted = false;

  ImageSearchState get _searchState => ref.read(imageSearchProvider(_scope));
  ImageSearch get _notifier => ref.read(imageSearchProvider(_scope).notifier);
  ImageSearchFilterState get _filterState => _searchState.filterState;

  @override
  void initState() {
    super.initState();
    _scope = ImageSearchScope(_resolveStateKey());
    _scrollController = ScrollController();
    _textController = TextEditingController();
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
    if (oldWidget.initialInputKind != widget.initialInputKind) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _notifier.selectInputKind(widget.initialInputKind);
        }
      });
    }
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
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _scheduleInitialSourceBootstrap({bool initialize = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final capabilities = await ref.read(serverCapabilitiesProvider.future);
        if (!mounted || !capabilities.imageSearch) return;
      } catch (_) {
        return;
      }
      if (!mounted) {
        return;
      }
      if (initialize) {
        _notifier.initialize(
          widget.initialCurrentMovieScope,
          initialInputKind: widget.initialInputKind,
        );
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
    // 未选搜索条件前没有可刷新的结果。
    if (!_searchState.hasSource) return;
    await _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    final capabilities = ref.watch(serverCapabilitiesProvider);
    if (capabilities.isLoading)
      return const Center(child: CircularProgressIndicator());
    Future<void> retryCapabilities() async {
      ref.invalidate(serverCapabilitiesProvider);
      _scheduleInitialSourceBootstrap(initialize: true);
    }

    if (capabilities.hasError) {
      return isMobile
          ? AppMobileSectionError(
              title: l10n.imageSearchCapabilitiesLoadFailed,
              message: l10n.imageSearchCapabilitiesLoadFailedMessage,
              onRetry: retryCapabilities,
            )
          : AppSectionError(
              title: l10n.imageSearchCapabilitiesLoadFailed,
              message: l10n.imageSearchCapabilitiesLoadFailedMessage,
              onRetry: retryCapabilities,
            );
    }
    if (capabilities.value?.imageSearch == false) {
      return AppEmptyState(
        icon: Icons.image_search_outlined,
        title: l10n.imageSearchDisabledTitle,
        message: isMobile
            ? l10n.imageSearchDisabledMessageMobile
            : l10n.imageSearchDisabledMessageDesktop,
        onRetry: () => ref.invalidate(serverCapabilitiesProvider),
        retryLabel: l10n.imageSearchRecheck,
      );
    }
    final spacing = context.appSpacing;
    final searchState = ref.watch(imageSearchProvider(_scope));
    final loadMoreFooter = searchState.hasSource
        ? _buildLoadMoreFooter(context)
        : null;
    return AppPageRefreshScope(
      onRefresh: _handleTopBarRefresh,
      child: Material(
        color: Colors.transparent,
        child: AppPagedLoadMoreScope(
          canLoadMore: _canAutoLoadMore,
          onLoadMore: _autoLoadMoreForViewport,
          child: CustomScrollView(
            key: PageStorageKey<String>(
              'image-search-scroll:${_scope.cacheKey}',
            ),
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildSearchComposer(context)),
              if (searchState.inputKind == ImageSearchInputKind.image &&
                  searchState.hasSource &&
                  searchState.isPreviewExpanded) ...[
                SliverToBoxAdapter(child: SizedBox(height: spacing.sm)),
                SliverToBoxAdapter(child: _buildPreviewPanel(context)),
              ],
              SliverToBoxAdapter(child: SizedBox(height: spacing.md)),
              _buildResultSectionSliver(context),
              if (loadMoreFooter != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: spacing.md),
                    child: loadMoreFooter,
                  ),
                ),
              ...bottomSafeAreaSliver(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchComposer(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final searchState = _searchState;
    final modeSwitch = Container(
      key: const Key('image-search-mode-switch'),
      padding: EdgeInsets.all(spacing.xs),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.smBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            key: const Key('image-search-mode-image'),
            label: l10n.imageSearchModeImage,
            icon: const Icon(Icons.image_search_outlined),
            size: AppButtonSize.xSmall,
            variant: AppButtonVariant.secondary,
            isSelected: searchState.inputKind == ImageSearchInputKind.image,
            onPressed: () => _selectSearchMode(ImageSearchInputKind.image),
          ),
          AppButton(
            key: const Key('image-search-mode-text'),
            label: l10n.imageSearchModeText,
            icon: const Icon(Icons.text_fields_rounded),
            size: AppButtonSize.xSmall,
            variant: AppButtonVariant.secondary,
            isSelected: searchState.inputKind == ImageSearchInputKind.text,
            onPressed: () => _selectSearchMode(ImageSearchInputKind.text),
          ),
        ],
      ),
    );
    final searchInput = searchState.inputKind == ImageSearchInputKind.image
        ? _buildImageSearchInput(context)
        : _buildTextSearchInput(context);
    final filterButton = _buildFilterControl(context, searchState);

    return AppContentCard(
      key: const Key('desktop-image-search-source-card'),
      title: null,
      padding: EdgeInsets.all(spacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < context.appLayoutTokens.dialogWidthSm) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [modeSwitch, const Spacer(), filterButton]),
                SizedBox(height: spacing.md),
                searchInput,
              ],
            );
          }
          return Row(
            children: [
              modeSwitch,
              SizedBox(width: spacing.md),
              Expanded(child: searchInput),
              SizedBox(width: spacing.sm),
              filterButton,
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterControl(
    BuildContext context,
    ImageSearchState searchState,
  ) {
    final l10n = AppLocalizations.of(context);
    final isBusy =
        searchState.isSearching || searchState.isResolvingActorMovieIds;
    final isEnabled = searchState.hasSource && !isBusy;
    final hasActiveFilter = !searchState.filterState.isDefault;
    final icon = _buildFilterIcon(context, hasActiveFilter);

    final platform = AppPlatformScope.maybeOf(context);
    final usesMobileFilter =
        platform == AppPlatform.mobile ||
        (platform == null &&
            widget.resultPreviewPresentation ==
                ImageSearchResultPreviewPresentation.bottomDrawer);
    if (usesMobileFilter) {
      return AppIconButton(
        key: const Key('desktop-image-search-toggle-filter'),
        tooltip: isEnabled
            ? l10n.imageSearchAdvancedFilter
            : l10n.imageSearchFilterDisabledHint,
        semanticLabel: l10n.imageSearchAdvancedFilter,
        icon: icon,
        isSelected: hasActiveFilter,
        onPressed: isEnabled
            ? () => unawaited(_openMobileFilterDrawer())
            : null,
      );
    }

    final draft = _desktopFilterDraft ?? searchState.filterState;
    return AppGlassFilterPopover(
      key: const Key('desktop-image-search-filter-control'),
      panelKey: const Key('desktop-image-search-filter-panel'),
      scrollViewKey: const Key('desktop-image-search-filter-scroll-view'),
      scrollable: true,
      enabled: isEnabled,
      onOpened: () => setState(() {
        _desktopFilterDraft = searchState.filterState;
      }),
      panelBuilder: (_) => ImageSearchFilterPanel(
        filterState: draft,
        currentMovieNumber: widget.currentMovieNumber,
        onChanged: _updateDesktopFilterDraft,
        onSelectActors: () => unawaited(_selectDesktopActors()),
      ),
      footerBuilder: (context, close) => ImageSearchFilterFooter(
        filterState: draft,
        isSearching: isBusy,
        onReset: () =>
            _updateDesktopFilterDraft(const ImageSearchFilterState()),
        onApply: () {
          close();
          unawaited(_applyDesktopFilter(draft));
        },
      ),
      triggerBuilder: (context, toggle) => AppIconButton(
        key: const Key('desktop-image-search-toggle-filter'),
        tooltip: isEnabled
            ? l10n.imageSearchAdvancedFilter
            : l10n.imageSearchFilterDisabledHint,
        semanticLabel: l10n.imageSearchAdvancedFilter,
        icon: icon,
        isSelected: hasActiveFilter,
        onPressed: isEnabled ? toggle : null,
      ),
    );
  }

  Widget _buildFilterIcon(BuildContext context, bool hasActiveFilter) {
    const icon = Icon(Icons.tune_rounded);
    if (!hasActiveFilter) {
      return icon;
    }
    return Badge(
      backgroundColor: Theme.of(context).colorScheme.primary,
      smallSize: context.appSpacing.sm,
      child: icon,
    );
  }

  Widget _buildImageSearchInput(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final searchState = _searchState;
    if (!searchState.hasSource) {
      return Material(
        key: const Key('image-search-image-empty-input'),
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.smBorder,
        child: AppInteractiveSurface(
          key: const Key('desktop-image-search-empty-select-button'),
          onTap: _pickAndSearchImage,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.md,
              vertical: spacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: context.appComponentTokens.iconSizeSm,
                  color: context.appTextPalette.secondary,
                ),
                SizedBox(width: spacing.sm),
                Text(
                  l10n.imageSearchPickImage,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final preview = ClipRRect(
      borderRadius: context.appRadius.smBorder,
      child: SizedBox(
        key: const Key('desktop-image-search-source-thumbnail'),
        width: context.appComponentTokens.iconSize4xl * 2,
        child: MoviePlotThumbnail(
          imageProvider: MemoryImage(searchState.fileBytes!),
          maxHeight: context.appComponentTokens.iconSize4xl,
          fit: BoxFit.cover,
          borderRadius: context.appRadius.smBorder,
        ),
      ),
    );
    return Row(
      key: const Key('desktop-image-search-toolbar-group'),
      children: [
        preview,
        SizedBox(width: spacing.sm),
        Expanded(
          child: Text(
            searchState.fileName ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
        ),
        SizedBox(width: spacing.sm),
        AppButton(
          key: const Key('desktop-image-search-change-image'),
          label: l10n.imageSearchChangeImage,
          icon: const Icon(Icons.image_search_outlined),
          size: AppButtonSize.xSmall,
          onPressed: _pickAndSearchImage,
        ),
        SizedBox(width: spacing.xs),
        AppIconButton(
          key: const Key('desktop-image-search-toggle-preview'),
          tooltip: searchState.isPreviewExpanded
              ? l10n.imageSearchCollapsePreview
              : l10n.imageSearchExpandPreview,
          semanticLabel: searchState.isPreviewExpanded
              ? l10n.imageSearchCollapsePreview
              : l10n.imageSearchExpandPreview,
          size: AppIconButtonSize.mini,
          icon: Icon(
            searchState.isPreviewExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
          ),
          onPressed: _notifier.togglePreviewExpanded,
        ),
      ],
    );
  }

  Widget _buildPreviewPanel(BuildContext context) {
    return AppContentCard(
      key: const Key('desktop-image-search-preview-panel'),
      title: AppLocalizations.of(context).imageSearchPreviewTitle,
      child: Center(
        child: MoviePlotThumbnail(
          imageProvider: MemoryImage(_searchState.fileBytes!),
          maxHeight: context.appLayoutTokens.dialogWidthSm,
          fit: BoxFit.contain,
          borderRadius: context.appRadius.mdBorder,
        ),
      ),
    );
  }

  Widget _buildTextSearchInput(BuildContext context) {
    final textQuery = _searchState.textQuery;
    if (textQuery != null &&
        textQuery.isNotEmpty &&
        _textController.text != textQuery) {
      _textController.text = textQuery;
    }
    return CatalogSearchField(
      fieldKey: const Key('image-search-text-source-field'),
      searchButtonKey: const Key('image-search-text-source-search-button'),
      controller: _textController,
      hintText: AppLocalizations.of(context).imageSearchTextHint,
      searchButtonTooltip: AppLocalizations.of(context).imageSearchSearchAction,
      isSearching: _searchState.isSearching,
      onSearchTap: _searchText,
      onSubmitted: (_) => _searchText(),
    );
  }

  Widget _buildResultSectionSliver(BuildContext context) {
    final searchState = _searchState;
    if (!searchState.hasSource) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (searchState.isSearching && searchState.items.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.appLayoutTokens.emptySectionVerticalPadding,
            ),
            child: CircularProgressIndicator.adaptive(
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
      return SliverToBoxAdapter(
        child: AppEmptyState(
          message: AppLocalizations.of(context).imageSearchEmpty,
        ),
      );
    }

    return ImageSearchResultSliver(
      items: searchState.items,
      onItemTap: _openResultPreviewDialog,
      onItemMenuRequested: _showResultActions,
      onItemSearchSimilar: (item) => unawaited(_searchSimilarFromResult(item)),
      onItemSaveToLocal: (item) => unawaited(_saveResultImageToLocal(item)),
      onItemPlay: _openPlayerForResult,
      onItemMovieDetail: _openMovieDetailForResult,
    );
  }

  Widget? _buildLoadMoreFooter(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            child: CircularProgressIndicator.adaptive(
              strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
            ),
          ),
        ),
      );
    }

    if (!_hasLoadMoreError) {
      if (!_autoLoadHalted || !searchState.hasMore) {
        return null;
      }
      // 连续多页没有可见新增时自动补页会主动停下；保留一个显式出口，避免
      // hasMore 仍为 true 时列表被静默截断。
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
                Text(
                  l10n.imageSearchAutoLoadPaused,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
                SizedBox(width: spacing.sm),
                TextButton(
                  onPressed: _loadMoreManually,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.sm,
                      vertical: spacing.xs,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.imageSearchContinueLoading),
                ),
              ],
            ),
          ),
        ),
      );
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
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runSearch() {
    _resetAutoLoadState();
    return _notifier.search(
      filter: _filterState,
      currentMovieNumber: widget.currentMovieNumber,
    );
  }

  void _resetAutoLoadState() {
    _autoLoadNoGrowthStreak = 0;
    _autoLoadHalted = false;
  }

  bool get _hasLoadMoreError =>
      _searchState.isLoadMoreFailed && _searchState.items.isNotEmpty;

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

  bool _canAutoLoadMore() {
    final searchState = _searchState;
    if (!searchState.hasMore ||
        searchState.isSearching ||
        searchState.isLoadingMore ||
        _autoLoadHalted ||
        _hasLoadMoreError) {
      return false;
    }
    if (searchState.items.isEmpty) {
      final currentMovieNumber = widget.currentMovieNumber?.trim();
      return _filterState.currentMovieScope !=
              ImageSearchCurrentMovieScope.all &&
          currentMovieNumber != null &&
          currentMovieNumber.isNotEmpty;
    }
    return true;
  }

  Future<void> _autoLoadMoreForViewport() async {
    final baselineItemCount = _searchState.items.length;
    await _notifier.loadMore();
    if (!mounted) {
      return;
    }
    final hasVisibleGrowth = _searchState.items.length > baselineItemCount;
    if (hasVisibleGrowth) {
      _autoLoadNoGrowthStreak = 0;
    } else {
      _autoLoadNoGrowthStreak += 1;
    }
    if (_autoLoadNoGrowthStreak >= _maxAutoLoadNoGrowthStreak) {
      if (!_autoLoadHalted) {
        setState(() => _autoLoadHalted = true);
      }
    }
  }

  /// 用户手动继续加载：成功拿到可见新增后恢复自动补页。
  Future<void> _loadMoreManually() async {
    if (_searchState.isLoadingMore) {
      return;
    }
    final baselineItemCount = _searchState.items.length;
    await _notifier.loadMore();
    if (!mounted) {
      return;
    }
    if (_searchState.items.length > baselineItemCount) {
      setState(() {
        _autoLoadNoGrowthStreak = 0;
        _autoLoadHalted = false;
      });
    }
  }

  void _updateDesktopFilterDraft(ImageSearchFilterState filter) {
    setState(() => _desktopFilterDraft = filter);
  }

  Future<void> _applyDesktopFilter(ImageSearchFilterState filter) async {
    _notifier.updateFilter(filter);
    await _runSearch();
  }

  Future<void> _openMobileFilterDrawer() async {
    final filter = await showMobileImageSearchFilterDrawer(
      context,
      initialFilter: _filterState,
      currentMovieNumber: widget.currentMovieNumber,
      isSearching:
          _searchState.isSearching || _searchState.isResolvingActorMovieIds,
      loadActors: _loadSubscribedActors,
    );
    if (!mounted || filter == null) {
      return;
    }
    _notifier.updateFilter(filter);
    await _runSearch();
  }

  Future<List<ActorListItemDto>?> _loadSubscribedActors() async {
    await _notifier.ensureSubscribedActorsLoaded();
    if (!mounted) {
      return null;
    }
    final errorMessage = _searchState.subscribedActorsErrorMessage;
    if (errorMessage != null) {
      showToast(errorMessage, tone: AppToastTone.error);
      return null;
    }
    return _searchState.subscribedActors;
  }

  Future<void> _selectDesktopActors() async {
    final actors = await _loadSubscribedActors();
    if (!mounted || actors == null) {
      return;
    }
    final draft = _desktopFilterDraft ?? _filterState;
    await showActorSelectorDialog(
      context,
      actors: actors,
      initialSelectedActors: draft.selectedActors,
      onSelectionChanged: (selectedActors) {
        if (!mounted) {
          return;
        }
        _updateDesktopFilterDraft(
          (_desktopFilterDraft ?? _filterState).copyWith(
            selectedActors: selectedActors,
          ),
        );
      },
    );
  }

  Future<void> _pickAndSearchImage() async {
    try {
      final pickedFile = await widget.imagePicker(AppLocalizations.of(context));
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
        showToast(error.message, tone: AppToastTone.error);
      }
    } catch (_) {
      if (mounted) {
        showToast(
          AppLocalizations.of(context).imageSearchPickImageFailed,
          tone: AppToastTone.error,
        );
      }
    }
  }

  void _selectSearchMode(ImageSearchInputKind inputKind) {
    _notifier.selectInputKind(inputKind);
  }

  Future<void> _searchText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      showToast(
        AppLocalizations.of(context).imageSearchTextRequired,
        tone: AppToastTone.warning,
      );
      return;
    }
    _notifier.setTextSource(text);
    await _runSearch();
  }

  Future<void> _openResultPreviewDialog(ImageSearchResultItemDto item) async {
    int? selectedActorId;
    final presentation =
        widget.resultPreviewPresentation ==
            ImageSearchResultPreviewPresentation.bottomDrawer
        ? MediaPreviewPresentation.bottomDrawer
        : MediaPreviewPresentation.dialog;
    final action = await showMediaPreviewOverlay(
      context: context,
      presentation: presentation,
      drawerKey: presentation == MediaPreviewPresentation.bottomDrawer
          ? const Key('image-search-result-preview-bottom-sheet')
          : null,
      builder: (_) {
        return ImageSearchResultPreviewDialog(
          item: item,
          presentation: presentation,
          onActorSelected: (actorId) => selectedActorId = actorId,
        );
      },
    );
    if (!mounted) {
      return;
    }
    final actorId = selectedActorId;
    if (actorId != null) {
      if (widget.onOpenActorDetail != null) {
        widget.onOpenActorDetail!(context, actorId);
      } else {
        context.pushDesktopActorDetail(
          actorId: actorId,
          fallbackPath: desktopImageSearchPath,
        );
      }
      return;
    }
    if (action == null) return;
    switch (action) {
      case MediaPreviewAction.searchSimilar:
        await _searchSimilarFromResult(item);
      case MediaPreviewAction.play:
        _openPlayerForResult(item);
      case MediaPreviewAction.openMovieDetail:
        _openMovieDetailForResult(item);
      case MediaPreviewAction.addToCollection:
        await _addResultToCollection(item);
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
        showToast(
          AppLocalizations.of(context).imageSearchReadResultImageFailed,
          tone: AppToastTone.error,
        );
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
    unawaited(
      launchMoviePlayback(
        context,
        movieNumber: item.movieNumber,
        mediaId: item.mediaId > 0 ? item.mediaId : null,
        positionSeconds: item.offsetSeconds,
        inAppFallbackPath: desktopImageSearchPath,
      ),
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
    return item.image.origin.trim();
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
    final action = await showAppActionMenu<AppImageActionType>(
      context: context,
      globalPosition: globalPosition,
      items: buildImageActionMenuItems(
        _buildResultActionDescriptors(item, point),
      ),
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
    final l10n = AppLocalizations.of(context);
    final hasMedia = item.mediaId > 0;
    return <AppImageActionDescriptor>[
      AppImageActionDescriptor(
        type: AppImageActionType.searchSimilar,
        label: l10n.imageSearchSimilarAction,
        icon: Icons.image_search_outlined,
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.saveToLocal,
        label: l10n.imageSearchSaveToLocal,
        icon: Icons.download_outlined,
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.toggleMark,
        label: point == null
            ? l10n.imageSearchAddMark
            : l10n.imageSearchRemoveMark,
        icon: point == null
            ? Icons.bookmark_add_outlined
            : Icons.bookmark_remove_outlined,
        enabled: hasMedia,
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.addToCollection,
        label: l10n.imageSearchAddToCollection,
        icon: Icons.collections_bookmark_outlined,
        enabled: hasMedia && item.thumbnailId > 0,
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.play,
        label: l10n.imageSearchPlay,
        icon: Icons.play_circle_outline_rounded,
        enabled: hasMedia,
      ),
      AppImageActionDescriptor(
        type: AppImageActionType.movieDetail,
        label: l10n.imageSearchMovieDetail,
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
      case AppImageActionType.addToCollection:
        await _addResultToCollection(item, point: point);
        break;
      case AppImageActionType.play:
        _openPlayerForResult(item);
        break;
      case AppImageActionType.setCover:
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
    final l10n = AppLocalizations.of(context);
    final result =
        await ImageSaveService(
          fetchBytes: ref.read(apiClientProvider).getBytes,
        ).saveImageFromUrl(
          imageUrl: _resultImageUrl(item),
          fileName: _resultImageFileName(item),
          dialogTitle: l10n.imageSearchSaveToLocal,
          l10n: l10n,
        );
    if (!mounted) {
      return;
    }
    if (result.status == ImageSaveStatus.success) {
      showToast(
        result.message ?? l10n.imageSearchImageSaved,
        tone: AppToastTone.success,
      );
    }
    if (result.status == ImageSaveStatus.failed) {
      showToast(
        result.message ?? l10n.imageSearchSaveFailed,
        tone: AppToastTone.error,
      );
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
          showToast(
            AppLocalizations.of(context).imageSearchMarkAdded,
            tone: AppToastTone.success,
          );
        }
        return;
      }
      await ref.read(mediaApiProvider).deleteMediaPoint(pointId: point.pointId);
      if (mounted) {
        showToast(
          AppLocalizations.of(context).imageSearchMarkRemoved,
          tone: AppToastTone.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showToast(
          AppLocalizations.of(context).imageSearchMarkUpdateFailed,
          tone: AppToastTone.error,
        );
      }
    }
  }

  Future<void> _addResultToCollection(
    ImageSearchResultItemDto item, {
    MediaPointDto? point,
  }) async {
    if (item.mediaId <= 0 || item.thumbnailId <= 0) {
      return;
    }
    final existingPoint = point ?? await _loadMatchingPoint(item);
    if (!mounted) {
      return;
    }
    await showAddToMomentCollectionDialog(
      context,
      pointId: existingPoint?.pointId,
      mediaId: existingPoint == null ? item.mediaId : null,
      thumbnailId: existingPoint == null ? item.thumbnailId : null,
    );
  }
}
