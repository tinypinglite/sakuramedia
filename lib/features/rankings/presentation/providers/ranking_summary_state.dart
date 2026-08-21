import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/rankings/data/ranked_movie_list_item_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_subscription_mutation_mixin.dart';
import 'package:sakuramedia/features/rankings/data/ranking_board_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_sort.dart';
import 'package:sakuramedia/features/rankings/data/ranking_source_dto.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

@immutable
class RankingFilterState {
  const RankingFilterState({
    this.isLoading = true,
    this.errorMessage,
    this.sources = const <RankingSourceDto>[],
    this.boards = const <RankingBoardDto>[],
    this.selectedSource,
    this.selectedBoard,
    this.selectedPeriod,
    this.selectedSortField,
    this.selectedSortDirection = SortDirection.desc,
  });

  static const RankingFilterState initial = RankingFilterState();

  final bool isLoading;
  final String? errorMessage;
  final List<RankingSourceDto> sources;
  final List<RankingBoardDto> boards;
  final RankingSourceDto? selectedSource;
  final RankingBoardDto? selectedBoard;
  final String? selectedPeriod;
  final RankingSortField? selectedSortField;
  final SortDirection selectedSortDirection;

  bool get hasNoSources =>
      sources.isEmpty && !isLoading && errorMessage == null;

  String? get sortExpression {
    final field = selectedSortField;
    return field == null
        ? null
        : '${field.apiValue}:${selectedSortDirection.apiValue}';
  }

  RankingFilterState copyWith({
    bool? isLoading,
    Object? errorMessage = _sentinel,
    List<RankingSourceDto>? sources,
    List<RankingBoardDto>? boards,
    Object? selectedSource = _sentinel,
    Object? selectedBoard = _sentinel,
    Object? selectedPeriod = _sentinel,
    Object? selectedSortField = _sentinel,
    SortDirection? selectedSortDirection,
  }) {
    return RankingFilterState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          identical(errorMessage, _sentinel)
              ? this.errorMessage
              : errorMessage as String?,
      sources: List<RankingSourceDto>.unmodifiable(sources ?? this.sources),
      boards: List<RankingBoardDto>.unmodifiable(boards ?? this.boards),
      selectedSource:
          identical(selectedSource, _sentinel)
              ? this.selectedSource
              : selectedSource as RankingSourceDto?,
      selectedBoard:
          identical(selectedBoard, _sentinel)
              ? this.selectedBoard
              : selectedBoard as RankingBoardDto?,
      selectedPeriod:
          identical(selectedPeriod, _sentinel)
              ? this.selectedPeriod
              : selectedPeriod as String?,
      selectedSortField:
          identical(selectedSortField, _sentinel)
              ? this.selectedSortField
              : selectedSortField as RankingSortField?,
      selectedSortDirection:
          selectedSortDirection ?? this.selectedSortDirection,
    );
  }
}

const Object _sentinel = Object();

@immutable
class RankingSummaryState
    implements
        SubscriptionMovieListState<
          RankingSummaryState,
          RankedMovieListItemDto
        > {
  const RankingSummaryState({
    required this.paged,
    required this.filters,
    this.isListLoading = false,
    this.initialErrorMessage,
    this.subscriptionUpdatingMovieNumbers = const <String>{},
  });

  static const RankingSummaryState initial = RankingSummaryState(
    paged: PagedListState<RankedMovieListItemDto>(),
    filters: RankingFilterState.initial,
  );

  @override
  final PagedListState<RankedMovieListItemDto> paged;
  final RankingFilterState filters;
  final bool isListLoading;
  final String? initialErrorMessage;
  @override
  final Set<String> subscriptionUpdatingMovieNumbers;

  bool isSubscriptionUpdating(String movieNumber) =>
      subscriptionUpdatingMovieNumbers.contains(movieNumber);

  RankingSummaryState copyWith({
    PagedListState<RankedMovieListItemDto>? paged,
    RankingFilterState? filters,
    bool? isListLoading,
    Object? initialErrorMessage = _sentinel,
    Set<String>? subscriptionUpdatingMovieNumbers,
  }) {
    return RankingSummaryState(
      paged: paged ?? this.paged,
      filters: filters ?? this.filters,
      isListLoading: isListLoading ?? this.isListLoading,
      initialErrorMessage:
          identical(initialErrorMessage, _sentinel)
              ? this.initialErrorMessage
              : initialErrorMessage as String?,
      subscriptionUpdatingMovieNumbers: Set<String>.unmodifiable(
        subscriptionUpdatingMovieNumbers ??
            this.subscriptionUpdatingMovieNumbers,
      ),
    );
  }

  @override
  RankingSummaryState applySubscriptionMutation({
    PagedListState<RankedMovieListItemDto>? paged,
    Set<String>? subscriptionUpdatingMovieNumbers,
  }) => copyWith(
    paged: paged,
    subscriptionUpdatingMovieNumbers: subscriptionUpdatingMovieNumbers,
  );
}
