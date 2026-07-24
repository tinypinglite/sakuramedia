import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/downloads/data/download_candidate_dto.dart';
import 'package:sakuramedia/features/downloads/data/download_request_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/detail/movie_detail_magnet_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('search populates items and clears loading', () async {
    final controller = MovieDetailMagnetController(
      movieNumber: 'ABC-001',
      searchCandidates:
          ({required movieNumber, indexerKind}) async => <DownloadCandidateDto>[
            _candidate(title: 'a', sizeBytes: 100, seeders: 1),
          ],
      createDownloadRequest: _unusedCreateDownloadRequest,
    );
    addTearDown(controller.dispose);

    await controller.search();

    expect(controller.items, hasLength(1));
    expect(controller.isLoading, isFalse);
    expect(controller.hasSearched, isTrue);
    expect(controller.errorMessage, isNull);
  });

  test('search surfaces a friendly message and empties items on failure', () async {
    final controller = MovieDetailMagnetController(
      movieNumber: 'ABC-001',
      searchCandidates: ({required movieNumber, indexerKind}) async {
        throw Exception('boom');
      },
      createDownloadRequest: _unusedCreateDownloadRequest,
    );
    addTearDown(controller.dispose);

    await controller.search();

    expect(controller.items, isEmpty);
    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, '搜索资源失败，请稍后重试。');
  });

  // 回归：检查器面板在请求飞行途中被关闭（宿主 dispose 控制器），响应回来后
  // finally 里的 notify 不能再抛 "used after being disposed"。
  test('search completing after dispose does not throw', () async {
    final gate = Completer<List<DownloadCandidateDto>>();
    final controller = MovieDetailMagnetController(
      movieNumber: 'ABC-001',
      searchCandidates: ({required movieNumber, indexerKind}) => gate.future,
      createDownloadRequest: _unusedCreateDownloadRequest,
    );

    final pending = controller.search();
    controller.dispose();
    gate.complete(<DownloadCandidateDto>[]);

    await expectLater(pending, completes);
  });

  test('search failing after dispose does not throw', () async {
    final gate = Completer<List<DownloadCandidateDto>>();
    final controller = MovieDetailMagnetController(
      movieNumber: 'ABC-001',
      searchCandidates: ({required movieNumber, indexerKind}) => gate.future,
      createDownloadRequest: _unusedCreateDownloadRequest,
    );

    final pending = controller.search();
    controller.dispose();
    gate.completeError(Exception('boom'));

    await expectLater(pending, completes);
  });

  test('submitCandidate completing after dispose does not throw', () async {
    final gate = Completer<DownloadRequestResponseDto>();
    final controller = MovieDetailMagnetController(
      movieNumber: 'ABC-001',
      searchCandidates:
          ({required movieNumber, indexerKind}) async =>
              const <DownloadCandidateDto>[],
      createDownloadRequest:
          ({required movieNumber, required clientId, required candidate}) =>
              gate.future,
    );

    final pending = controller.submitCandidate(
      _candidate(title: 'a', sizeBytes: 100, seeders: 1),
      clientId: 1,
    );
    controller.dispose();
    gate.completeError(Exception('boom'));

    await expectLater(pending, throwsA(isA<Exception>()));
  });
}

DownloadCandidateDto _candidate({
  required String title,
  required int sizeBytes,
  required int seeders,
}) {
  return DownloadCandidateDto(
    source: 'indexer',
    indexerName: 'demo',
    indexerKind: 'bt',
    resolvedClientId: 1,
    resolvedClientName: 'qb',
    movieNumber: 'ABC-001',
    title: title,
    sizeBytes: sizeBytes,
    seeders: seeders,
    magnetUrl: 'magnet:?xt=urn:btih:$title',
    torrentUrl: '',
    tags: const <String>[],
  );
}

Future<DownloadRequestResponseDto> _unusedCreateDownloadRequest({
  required String movieNumber,
  required int clientId,
  required DownloadCandidateDto candidate,
}) async {
  throw StateError('not expected in this test');
}
