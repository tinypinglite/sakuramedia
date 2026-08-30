import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/image_search/data/image_search_target.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/image_search/presentation/widgets/actor_selector_dialog.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';

const double _imageSearchFilterDrawerMaxHeightFactor = 0.72;

Future<ImageSearchFilterState?> showMobileImageSearchFilterDrawer(
  BuildContext context, {
  required ImageSearchFilterState initialFilter,
  required Future<List<ActorListItemDto>?> Function() loadActors,
  required bool isSearching,
  String? currentMovieNumber,
}) {
  return showAppBottomDrawer<ImageSearchFilterState>(
    context: context,
    drawerKey: const Key('mobile-image-search-filter-drawer'),
    maxHeightFactor: _imageSearchFilterDrawerMaxHeightFactor,
    builder: (_) => _MobileImageSearchFilterDrawer(
      initialFilter: initialFilter,
      currentMovieNumber: currentMovieNumber,
      loadActors: loadActors,
      isSearching: isSearching,
    ),
  );
}

class _MobileImageSearchFilterDrawer extends StatefulWidget {
  const _MobileImageSearchFilterDrawer({
    required this.initialFilter,
    required this.loadActors,
    required this.isSearching,
    this.currentMovieNumber,
  });

  final ImageSearchFilterState initialFilter;
  final Future<List<ActorListItemDto>?> Function() loadActors;
  final bool isSearching;
  final String? currentMovieNumber;

  @override
  State<_MobileImageSearchFilterDrawer> createState() =>
      _MobileImageSearchFilterDrawerState();
}

class _MobileImageSearchFilterDrawerState
    extends State<_MobileImageSearchFilterDrawer> {
  late ImageSearchFilterState _draft;
  List<ActorListItemDto> _actors = const <ActorListItemDto>[];
  bool _isLoadingActors = false;
  bool _isSelectingActors = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    if (_isSelectingActors) {
      return ImageSearchActorSelectorBody(
        actors: _actors,
        initialSelectedActors: _draft.selectedActors,
        onCancel: () => setState(() => _isSelectingActors = false),
        onDone: (selectedActors) {
          setState(() {
            _draft = _draft.copyWith(selectedActors: selectedActors);
            _isSelectingActors = false;
          });
        },
      );
    }

    return AppMobileFilterDrawerScaffold(
      scrollViewKey: const Key('mobile-image-search-filter-scroll-view'),
      footer: ImageSearchFilterFooter(
        filterState: _draft,
        isSearching: widget.isSearching,
        onReset: () => setState(() {
          _draft = const ImageSearchFilterState();
        }),
        onApply: () => Navigator.of(context).pop(_draft),
      ),
      child: ImageSearchFilterPanel(
        key: const Key('mobile-image-search-filter-panel'),
        filterState: _draft,
        currentMovieNumber: widget.currentMovieNumber,
        isLoadingActors: _isLoadingActors,
        onChanged: (filter) => setState(() => _draft = filter),
        onSelectActors: _openActorSelector,
      ),
    );
  }

  Future<void> _openActorSelector() async {
    setState(() => _isLoadingActors = true);
    final actors = await widget.loadActors();
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingActors = false;
      if (actors != null) {
        _actors = actors;
        _isSelectingActors = true;
      }
    });
  }
}

class ImageSearchFilterPanel extends StatelessWidget {
  const ImageSearchFilterPanel({
    super.key,
    required this.filterState,
    required this.onChanged,
    required this.onSelectActors,
    this.currentMovieNumber,
    this.isLoadingActors = false,
  });

  final ImageSearchFilterState filterState;
  final ValueChanged<ImageSearchFilterState> onChanged;
  final VoidCallback onSelectActors;
  final String? currentMovieNumber;
  final bool isLoadingActors;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final hasCurrentMovie =
        currentMovieNumber != null && currentMovieNumber!.trim().isNotEmpty;

    return Column(
      key: const Key('image-search-filter-sections'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FilterSection(
          title: '搜索素材',
          child: Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: [
              for (final target in ImageSearchTarget.values)
                AppButton(
                  key: Key('image-search-filter-target-${target.name}'),
                  label: target.label,
                  size: AppButtonSize.xSmall,
                  variant: AppButtonVariant.secondary,
                  isSelected: filterState.searchTarget == target,
                  onPressed: () =>
                      onChanged(filterState.copyWith(searchTarget: target)),
                ),
            ],
          ),
        ),
        if (hasCurrentMovie) ...[
          SizedBox(height: spacing.md),
          _FilterSection(
            title: '影片范围',
            child: Wrap(
              spacing: spacing.sm,
              runSpacing: spacing.sm,
              children: [
                for (final scope in ImageSearchCurrentMovieScope.values)
                  AppButton(
                    key: Key('image-search-filter-movie-${scope.name}'),
                    label: scope.label,
                    size: AppButtonSize.xSmall,
                    variant: AppButtonVariant.secondary,
                    isSelected: filterState.currentMovieScope == scope,
                    onPressed: () => onChanged(
                      filterState.copyWith(currentMovieScope: scope),
                    ),
                  ),
              ],
            ),
          ),
        ],
        SizedBox(height: spacing.md),
        _FilterSection(
          title: '女优范围',
          child: Wrap(
            spacing: spacing.sm,
            runSpacing: spacing.sm,
            children: [
              for (final mode in ImageSearchActorFilterMode.values)
                AppButton(
                  key: Key('image-search-filter-actor-${mode.name}'),
                  label: mode.label,
                  size: AppButtonSize.xSmall,
                  variant: AppButtonVariant.secondary,
                  isSelected: filterState.actorFilterMode == mode,
                  onPressed: () =>
                      onChanged(filterState.copyWith(actorFilterMode: mode)),
                ),
            ],
          ),
        ),
        if (filterState.requiresActorSelection) ...[
          SizedBox(height: spacing.md),
          AppButton(
            key: const Key('image-search-filter-select-actors'),
            label: filterState.selectedActors.isEmpty
                ? '选择已订阅女优'
                : '已选 ${filterState.selectedActorCount} 位',
            icon: const Icon(Icons.groups_2_outlined),
            trailingIcon: const Icon(Icons.chevron_right_rounded),
            size: AppButtonSize.small,
            variant: AppButtonVariant.secondary,
            isLoading: isLoadingActors,
            onPressed: isLoadingActors ? null : onSelectActors,
          ),
          if (filterState.selectedActors.isEmpty) ...[
            SizedBox(height: spacing.xs),
            Text(
              '请选择至少一位女优',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.error,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class ImageSearchFilterFooter extends StatelessWidget {
  const ImageSearchFilterFooter({
    super.key,
    required this.filterState,
    required this.onReset,
    required this.onApply,
    this.isSearching = false,
  });

  final ImageSearchFilterState filterState;
  final VoidCallback onReset;
  final VoidCallback onApply;
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppButton(
          key: const Key('image-search-filter-reset'),
          label: '重置',
          size: AppButtonSize.xSmall,
          variant: AppButtonVariant.secondary,
          onPressed: filterState.isDefault ? null : onReset,
        ),
        const Spacer(),
        AppButton(
          key: const Key('image-search-filter-apply'),
          label: '应用并搜索',
          icon: const Icon(Icons.search_rounded),
          size: AppButtonSize.small,
          variant: AppButtonVariant.primary,
          isLoading: isSearching,
          onPressed:
              isSearching ||
                  (filterState.requiresActorSelection &&
                      filterState.selectedActors.isEmpty)
              ? null
              : onApply,
        ),
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(height: context.appSpacing.sm),
        child,
      ],
    );
  }
}
