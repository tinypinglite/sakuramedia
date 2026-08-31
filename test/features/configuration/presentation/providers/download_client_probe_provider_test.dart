import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_client_probe_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/download_client_diagnostics_dialog.dart';

DownloadClientTestResultDto _connectivity({
  required bool healthy,
  int elapsedMs = 20,
  String? errorMessage,
}) => DownloadClientTestResultDto(
  healthy: healthy,
  checkedAt: DateTime.utc(2026, 7, 4, 10),
  clientId: 1,
  clientName: 'client-a',
  baseUrl: 'http://qb.example',
  elapsedMs: elapsedMs,
  version: healthy ? '5.0.4' : null,
  webApiVersion: healthy ? '2.11.4' : null,
  error:
      errorMessage == null
          ? null
          : DownloadClientDiagnosticErrorDto(
            type: 'qbittorrent_request_error',
            message: errorMessage,
          ),
);

DownloadClientStorageTestResultDto _storage({
  required bool healthy,
  List<String> warnings = const <String>[],
}) => DownloadClientStorageTestResultDto(
  healthy: healthy,
  checkedAt: DateTime.utc(2026, 7, 4, 10, 5),
  clientId: 1,
  clientName: 'client-a',
  elapsedMs: 30,
  warnings: warnings,
  directoryMapping: const DownloadClientStorageDirectoryMappingResultDto(
    status: 'ok',
    clientSavePath: '/downloads',
    localRootPath: '/mnt/downloads',
    probeRemoteDir: '/downloads/.probe',
    probeLocalDir: '/mnt/downloads/.probe',
    sentinelVisibleToQb: true,
    error: null,
  ),
  hardlink: const DownloadClientStorageHardlinkResultDto(
    status: 'ok',
    supported: true,
    sourcePath: '/mnt/downloads/.probe/sentinel.txt',
    targetPath: '/library/.probe/sentinel.link',
    error: null,
  ),
);

void main() {
  ProviderContainer createContainer() {
    final container = ProviderContainer(retry: (_, __) => null);
    addTearDown(container.dispose);
    return container;
  }

  DownloadClientProbe probe(ProviderContainer container, Object scope) {
    container.listen(downloadClientProbeProvider(scope), (_, _) {});
    return container.read(downloadClientProbeProvider(scope).notifier);
  }

  DownloadClientProbeState state(ProviderContainer container, Object scope) =>
      container.read(downloadClientProbeProvider(scope));

  test('健康、失败和 warning 结果以不可变状态回写', () async {
    final container = createContainer();
    final scope = Object();
    final notifier = probe(container, scope);

    await notifier.runConnectivity(
      () async => _connectivity(healthy: true, elapsedMs: 42),
    );
    expect(
      state(container, scope).connectivityChipState,
      DownloadClientProbeChipState.healthy,
    );
    expect(state(container, scope).connectivityChipDetail, '42ms');
    expect(
      state(container, scope).connectivityTooltip,
      contains('qBittorrent 5.0.4'),
    );

    final bad = _connectivity(healthy: false, errorMessage: 'login failed');
    await notifier.runConnectivity(() async => bad);
    expect(
      state(container, scope).connectivityChipState,
      DownloadClientProbeChipState.unhealthy,
    );
    expect(state(container, scope).canReplayConnectivityDialog, isTrue);
    expect(
      state(container, scope).connectivityTooltip,
      contains('login failed'),
    );

    await notifier.runStorage(
      () async => _storage(healthy: true, warnings: const ['硬链接不可用，将回退复制']),
    );
    expect(
      state(container, scope).storageChipState,
      DownloadClientProbeChipState.warning,
    );
    expect(state(container, scope).storageChipDetail, '有警告');
    expect(state(container, scope).canReplayStorageDialog, isTrue);
  });

  test('busy 去重、异常回落与 reset 保持既有语义', () async {
    final container = createContainer();
    final scope = Object();
    final notifier = probe(container, scope);
    final blocker = Completer<DownloadClientTestResultDto>();

    final first = notifier.runConnectivity(() => blocker.future);
    expect(state(container, scope).busy, isTrue);
    expect(
      await notifier.runStorage(() async => _storage(healthy: true)),
      isNull,
    );
    blocker.complete(_connectivity(healthy: true));
    await first;

    await expectLater(
      notifier.runStorage(() async => throw StateError('boom')),
      throwsA(isA<StateError>()),
    );
    expect(
      state(container, scope).storageChipState,
      DownloadClientProbeChipState.notTested,
    );
    expect(state(container, scope).busy, isFalse);

    notifier.applyStorageResult(_storage(healthy: false));
    expect(state(container, scope).canReplayStorageDialog, isTrue);
    notifier.reset();
    expect(state(container, scope), const DownloadClientProbeState());
  });

  test('scope 隔离，容器销毁后的迟到回包不再写状态', () async {
    final container = createContainer();
    final firstScope = Object();
    final secondScope = Object();
    final first = probe(container, firstScope);
    final second = probe(container, secondScope);

    first.applyConnectivityResult(_connectivity(healthy: true));
    expect(state(container, secondScope).connectivityResult, isNull);

    final lateContainer = ProviderContainer(retry: (_, __) => null);
    final lateScope = Object();
    lateContainer.listen(downloadClientProbeProvider(lateScope), (_, _) {});
    final lateProbe = lateContainer.read(
      downloadClientProbeProvider(lateScope).notifier,
    );
    final completer = Completer<DownloadClientTestResultDto>();
    final pending = lateProbe.runConnectivity(() => completer.future);
    lateContainer.dispose();
    completer.complete(_connectivity(healthy: true));
    expect(await pending, isNull);
    expect(second.state.connectivityResult, isNull);
  });

  test('probeChipDetail 不展示 0ms，且正确映射其他 chip', () {
    expect(
      probeChipDetail(DownloadClientProbeChipState.healthy, elapsedMs: 0),
      isNull,
    );
    expect(
      probeChipDetail(DownloadClientProbeChipState.healthy, elapsedMs: 15),
      '15ms',
    );
    expect(probeChipDetail(DownloadClientProbeChipState.warning), '有警告');
    expect(probeChipDetail(DownloadClientProbeChipState.unhealthy), '异常');
  });
}
