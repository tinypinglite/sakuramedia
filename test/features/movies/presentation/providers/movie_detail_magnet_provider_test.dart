import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_magnet_provider.dart';

void main() {
  test('policy rank sorting puts eligible candidates first by rank', () {
    final state = MovieDetailMagnetState(
      items: <DownloadCandidateDto>[
        _candidate('filtered', eligible: false),
        _candidate('rank2', eligible: true, rank: 2),
        _candidate('rank1', eligible: true, rank: 1),
      ],
    );

    expect(state.sortedItems.map((item) => item.title), <String>[
      'rank1',
      'rank2',
      'filtered',
    ]);
  });

  test('equal policy ranks preserve the API order', () {
    final state = MovieDetailMagnetState(
      items: <DownloadCandidateDto>[
        _candidate('first', eligible: true, rank: 1),
        _candidate('second', eligible: true, rank: 1),
      ],
    );

    expect(state.sortedItems.map((item) => item.title), <String>[
      'first',
      'second',
    ]);
  });

  test('legacy candidates without evaluation preserve the API order', () {
    final state = MovieDetailMagnetState(
      items: <DownloadCandidateDto>[_candidate('first'), _candidate('second')],
    );

    expect(state.sortedItems.map((item) => item.title), <String>[
      'first',
      'second',
    ]);
  });

  test('policy rank does not expose a meaningful sort direction', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(
      movieDetailMagnetProvider('ABC-001').notifier,
    );

    expect(
      notifier.state.selectedSortDirection,
      MovieDetailMagnetSortDirection.desc,
    );
    notifier.toggleSortDirection();
    expect(
      notifier.state.selectedSortDirection,
      MovieDetailMagnetSortDirection.desc,
    );

    notifier.setSortField(MovieDetailMagnetSortField.seeders);
    notifier.toggleSortDirection();
    expect(
      notifier.state.selectedSortDirection,
      MovieDetailMagnetSortDirection.asc,
    );
  });
}

DownloadCandidateDto _candidate(String title, {bool? eligible, int? rank}) {
  return DownloadCandidateDto(
    sourceUri: 'magnet:?xt=$title',
    indexerName: 'mteam',
    indexerKind: 'pt',
    resolvedClientId: 1,
    resolvedClientName: 'qb',
    movieNumber: 'ABC-001',
    title: title,
    sizeBytes: 1024,
    seeders: 1,
    selectionEvaluation: eligible == null
        ? null
        : DownloadCandidateSelectionEvaluationDto(
            eligible: eligible,
            selectionRank: rank,
          ),
  );
}
