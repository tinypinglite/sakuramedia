import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

part 'movie_detail_magnet_provider.g.dart';

enum MovieDetailMagnetSortField { policyRank, sizeBytes, seeders }

enum MovieDetailMagnetSortDirection { asc, desc }

extension MovieDetailMagnetSortFieldValue on MovieDetailMagnetSortField {
  /// 当前语言的排序字段名；展示层用这个取当前语言的文案。
  String labelWith(AppLocalizations l10n) => switch (this) {
    MovieDetailMagnetSortField.policyRank => l10n.movieMagnetSortPolicy,
    MovieDetailMagnetSortField.sizeBytes => l10n.mediaListSortFileSize,
    MovieDetailMagnetSortField.seeders => l10n.movieMagnetSortSeeders,
  };

  bool get supportsDirection => this != MovieDetailMagnetSortField.policyRank;
}

extension MovieDetailMagnetSortDirectionValue
    on MovieDetailMagnetSortDirection {
  bool get isAscending => this == MovieDetailMagnetSortDirection.asc;
}

@immutable
class MovieDetailMagnetState {
  const MovieDetailMagnetState({
    this.items = const <DownloadCandidateDto>[],
    this.selectedSortField = MovieDetailMagnetSortField.policyRank,
    this.selectedSortDirection = MovieDetailMagnetSortDirection.desc,
    this.isLoading = false,
    this.hasSearched = false,
    this.errorMessage,
    this.submittingCandidateKey,
  });

  static const MovieDetailMagnetState initial = MovieDetailMagnetState();

  final List<DownloadCandidateDto> items;
  final MovieDetailMagnetSortField selectedSortField;
  final MovieDetailMagnetSortDirection selectedSortDirection;
  final bool isLoading;
  final bool hasSearched;
  final String? errorMessage;
  final String? submittingCandidateKey;

  List<DownloadCandidateDto> get sortedItems {
    final positions = Map<DownloadCandidateDto, int>.identity();
    for (var index = 0; index < items.length; index++) {
      positions[items[index]] = index;
    }
    final sorted = List<DownloadCandidateDto>.from(items);
    sorted.sort((left, right) {
      final primary = _compare(left, right);
      if (primary != 0) return primary;
      return (positions[left] ?? 0).compareTo(positions[right] ?? 0);
    });
    return List<DownloadCandidateDto>.unmodifiable(sorted);
  }

  int _compare(DownloadCandidateDto left, DownloadCandidateDto right) {
    final primary = switch (selectedSortField) {
      MovieDetailMagnetSortField.policyRank => _comparePolicy(left, right),
      MovieDetailMagnetSortField.sizeBytes => left.sizeBytes.compareTo(
        right.sizeBytes,
      ),
      MovieDetailMagnetSortField.seeders => left.seeders.compareTo(
        right.seeders,
      ),
    };
    if (!selectedSortField.supportsDirection) return primary;
    return selectedSortDirection.isAscending ? primary : -primary;
  }

  int _comparePolicy(DownloadCandidateDto left, DownloadCandidateDto right) {
    final leftEvaluation = left.selectionEvaluation;
    final rightEvaluation = right.selectionEvaluation;
    if (leftEvaluation == null && rightEvaluation == null) return 0;
    if (leftEvaluation == null) return 1;
    if (rightEvaluation == null) return -1;
    if (leftEvaluation.eligible != rightEvaluation.eligible) {
      return leftEvaluation.eligible ? -1 : 1;
    }
    final leftRank = leftEvaluation.selectionRank ?? 1 << 30;
    final rightRank = rightEvaluation.selectionRank ?? 1 << 30;
    return leftRank.compareTo(rightRank);
  }

  MovieDetailMagnetState copyWith({
    List<DownloadCandidateDto>? items,
    MovieDetailMagnetSortField? selectedSortField,
    MovieDetailMagnetSortDirection? selectedSortDirection,
    bool? isLoading,
    bool? hasSearched,
    Object? errorMessage = _sentinel,
    Object? submittingCandidateKey = _sentinel,
  }) {
    return MovieDetailMagnetState(
      items: items ?? this.items,
      selectedSortField: selectedSortField ?? this.selectedSortField,
      selectedSortDirection:
          selectedSortDirection ?? this.selectedSortDirection,
      isLoading: isLoading ?? this.isLoading,
      hasSearched: hasSearched ?? this.hasSearched,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      submittingCandidateKey: identical(submittingCandidateKey, _sentinel)
          ? this.submittingCandidateKey
          : submittingCandidateKey as String?,
    );
  }
}

const Object _sentinel = Object();

@riverpod
class MovieDetailMagnet extends _$MovieDetailMagnet {
  bool _isDisposed = false;
  KeepAliveLink? _cacheLink;

  @override
  MovieDetailMagnetState build(String movieNumber) {
    ref.onDispose(() {
      _isDisposed = true;
      _cacheLink?.close();
      _cacheLink = null;
    });
    _cacheLink ??= ref.keepAlive();
    return MovieDetailMagnetState.initial;
  }

  KeepAliveLink? get cacheLink => _cacheLink;

  void setSortField(MovieDetailMagnetSortField field) {
    if (_isDisposed || state.selectedSortField == field) return;
    state = state.copyWith(selectedSortField: field);
  }

  void toggleSortDirection() {
    if (_isDisposed || !state.selectedSortField.supportsDirection) return;
    state = state.copyWith(
      selectedSortDirection:
          state.selectedSortDirection == MovieDetailMagnetSortDirection.desc
          ? MovieDetailMagnetSortDirection.asc
          : MovieDetailMagnetSortDirection.desc,
    );
  }

  Future<void> search() async {
    if (_isDisposed || state.isLoading) return;
    state = state.copyWith(
      isLoading: true,
      hasSearched: true,
      errorMessage: null,
    );

    try {
      final items = await ref
          .read(downloadsApiProvider)
          .searchCandidates(movieNumber: movieNumber);
      if (_isDisposed) return;
      state = state.copyWith(items: items, errorMessage: null);
    } catch (_) {
      if (_isDisposed) return;
      state = state.copyWith(
        items: const <DownloadCandidateDto>[],
        errorMessage: ref
            .read(appLocalizationsProvider)
            .movieProviderMagnetSearchFailed,
      );
    } finally {
      if (!_isDisposed) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<DownloadRequestResponseDto> submitCandidate(
    DownloadCandidateDto candidate, {
    required int clientId,
  }) async {
    if (state.submittingCandidateKey != null) {
      throw StateError('download request already running');
    }
    state = state.copyWith(submittingCandidateKey: candidate.submitKey);
    try {
      return await ref
          .read(downloadsApiProvider)
          .createDownloadRequest(
            movieNumber: movieNumber,
            clientId: clientId,
            candidate: candidate,
          );
    } finally {
      if (!_isDisposed) {
        state = state.copyWith(submittingCandidateKey: null);
      }
    }
  }
}
