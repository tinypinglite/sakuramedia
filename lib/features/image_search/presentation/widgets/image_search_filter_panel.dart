import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/image_search/data/image_search_target.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/image_search/presentation/widgets/actor_selector_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';
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
        isBottomDrawer: true,
        onBack: () => setState(() => _isSelectingActors = false),
        onSelectionChanged: (selectedActors) => setState(
          () => _draft = _draft.copyWith(selectedActors: selectedActors),
        ),
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
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final hasCurrentMovie =
        currentMovieNumber != null && currentMovieNumber!.trim().isNotEmpty;

    return Column(
      key: const Key('image-search-filter-sections'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFilterChoiceSection<ImageSearchTarget>(
          title: l10n.imageSearchMaterialTitle,
          items: [
            for (final target in ImageSearchTarget.values)
              AppSegmentedItem<ImageSearchTarget>(
                value: target,
                label: target.label(l10n),
                key: Key('image-search-filter-target-${target.name}'),
              ),
          ],
          selected: filterState.searchTarget,
          onChanged: (target) =>
              onChanged(filterState.copyWith(searchTarget: target)),
        ),
        if (hasCurrentMovie) ...[
          SizedBox(height: spacing.md),
          AppFilterChoiceSection<ImageSearchCurrentMovieScope>(
            title: l10n.imageSearchMovieScopeTitle,
            items: [
              for (final scope in ImageSearchCurrentMovieScope.values)
                AppSegmentedItem<ImageSearchCurrentMovieScope>(
                  value: scope,
                  label: scope.label(l10n),
                  key: Key('image-search-filter-movie-${scope.name}'),
                ),
            ],
            selected: filterState.currentMovieScope,
            onChanged: (scope) =>
                onChanged(filterState.copyWith(currentMovieScope: scope)),
          ),
        ],
        SizedBox(height: spacing.md),
        AppFilterChoiceSection<ImageSearchActorFilterMode>(
          title: l10n.imageSearchActorScopeTitle,
          items: [
            for (final mode in ImageSearchActorFilterMode.values)
              AppSegmentedItem<ImageSearchActorFilterMode>(
                value: mode,
                label: mode.label(l10n),
                key: Key('image-search-filter-actor-${mode.name}'),
              ),
          ],
          selected: filterState.actorFilterMode,
          onChanged: (mode) =>
              onChanged(filterState.copyWith(actorFilterMode: mode)),
        ),
        if (filterState.requiresActorSelection) ...[
          SizedBox(height: spacing.md),
          AppButton(
            key: const Key('image-search-filter-select-actors'),
            label: filterState.selectedActors.isEmpty
                ? l10n.imageSearchSelectSubscribedActors
                : l10n.imageSearchSelectedActorsCount(
                    filterState.selectedActorCount,
                  ),
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
              l10n.imageSearchSelectAtLeastOneActor,
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
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        AppButton(
          key: const Key('image-search-filter-reset'),
          label: l10n.imageSearchReset,
          size: AppButtonSize.xSmall,
          variant: AppButtonVariant.secondary,
          onPressed: filterState.isDefault ? null : onReset,
        ),
        const Spacer(),
        AppButton(
          key: const Key('image-search-filter-apply'),
          label: l10n.imageSearchApplyAndSearch,
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
