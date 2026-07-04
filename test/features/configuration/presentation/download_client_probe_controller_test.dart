import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/features/configuration/data/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/download_client_diagnostics_dialog.dart';
import 'package:sakuramedia/features/configuration/presentation/download_client_probe_controller.dart';

DownloadClientTestResultDto _connectivity({
  required bool healthy,
  int elapsedMs = 20,
  String? version = '5.0.4',
  String? webApi = '2.11.4',
  String? errorType,
  String? errorMessage,
}) {
  return DownloadClientTestResultDto(
    healthy: healthy,
    checkedAt: DateTime.utc(2026, 7, 4, 10),
    clientId: 1,
    clientName: 'client-a',
    baseUrl: 'http://qb.example',
    elapsedMs: elapsedMs,
    version: version,
    webApiVersion: webApi,
    error: errorType == null
        ? null
        : DownloadClientDiagnosticErrorDto(
            type: errorType,
            message: errorMessage ?? '',
          ),
  );
}

DownloadClientStorageTestResultDto _storage({
  required bool healthy,
  List<String> warnings = const <String>[],
  bool hardlinkSupported = true,
  String hardlinkStatus = 'ok',
  String? mappingErrorMessage,
}) {
  return DownloadClientStorageTestResultDto(
    healthy: healthy,
    checkedAt: DateTime.utc(2026, 7, 4, 10, 5),
    clientId: 1,
    clientName: 'client-a',
    elapsedMs: 30,
    warnings: warnings,
    directoryMapping: DownloadClientStorageDirectoryMappingResultDto(
      status: 'ok',
      clientSavePath: '/downloads',
      localRootPath: '/mnt/downloads',
      probeRemoteDir: '/downloads/.probe',
      probeLocalDir: '/mnt/downloads/.probe',
      sentinelVisibleToQb: true,
      error: mappingErrorMessage == null
          ? null
          : DownloadClientDiagnosticErrorDto(
              type: 'mapping_error',
              message: mappingErrorMessage,
            ),
    ),
    hardlink: DownloadClientStorageHardlinkResultDto(
      status: hardlinkStatus,
      supported: hardlinkSupported,
      sourcePath: '/mnt/downloads/.probe/sentinel.txt',
      targetPath: '/library/.probe/sentinel.link',
      error: null,
    ),
  );
}

void main() {
  group('DownloadClientProbeController', () {
    test('健康结果落定 → chip 变 healthy、detail 显示耗时、触发变更回调', () async {
      DownloadClientTestResultDto? emitted;
      final controller = DownloadClientProbeController(
        onConnectivityChanged: (result) => emitted = result,
      );
      addTearDown(controller.dispose);

      final ok = _connectivity(healthy: true, elapsedMs: 42);
      await controller.runConnectivity(() async => ok);

      expect(
        controller.connectivityChipState,
        DownloadClientProbeChipState.healthy,
      );
      expect(controller.connectivityChipDetail(), '42ms');
      expect(controller.canReplayConnectivityDialog, isFalse);
      expect(identical(emitted, ok), isTrue);
      // healthy 状态下 tooltip 拼版本 + 耗时
      expect(controller.connectivityTooltip(), contains('qBittorrent 5.0.4'));
      expect(controller.connectivityTooltip(), contains('42ms'));
    });

    test('业务失败 → chip 变 unhealthy 并允许 replay 详情', () async {
      final controller = DownloadClientProbeController();
      addTearDown(controller.dispose);

      final bad = _connectivity(
        healthy: false,
        version: null,
        webApi: null,
        errorType: 'qbittorrent_request_error',
        errorMessage: 'login failed',
      );
      await controller.runConnectivity(() async => bad);

      expect(
        controller.connectivityChipState,
        DownloadClientProbeChipState.unhealthy,
      );
      expect(controller.connectivityChipDetail(), '异常');
      expect(controller.canReplayConnectivityDialog, isTrue);
      expect(controller.connectivityTooltip(), contains('login failed'));
    });

    test('存储:warnings 非空 → chip 变 warning、tooltip 携带条目', () async {
      final controller = DownloadClientProbeController();
      addTearDown(controller.dispose);

      final warn = _storage(
        healthy: true,
        warnings: ['硬链接不可用，将回退复制'],
        hardlinkSupported: false,
        hardlinkStatus: 'failed',
      );
      await controller.runStorage(() async => warn);

      expect(controller.storageChipState, DownloadClientProbeChipState.warning);
      expect(controller.storageChipDetail(), '有警告');
      expect(controller.canReplayStorageDialog, isTrue);
      expect(controller.storageTooltip(), contains('硬链接不可用'));
      expect(controller.storageTooltip(), contains('硬链接不可用(将回退复制)'));
    });

    test('runConnectivity 抛错 → chip 回落到「未检测」且 rethrow', () async {
      final controller = DownloadClientProbeController();
      addTearDown(controller.dispose);

      await expectLater(
        controller.runConnectivity(() async => throw StateError('net')),
        throwsA(isA<StateError>()),
      );
      expect(
        controller.connectivityChipState,
        DownloadClientProbeChipState.notTested,
      );
      expect(controller.lastConnectivityResult, isNull);
      expect(controller.busy, isFalse);
    });

    test('runStorage 抛错 → 保留上次留存结果的态', () async {
      final controller = DownloadClientProbeController();
      addTearDown(controller.dispose);

      await controller.runStorage(() async => _storage(healthy: true));
      expect(controller.storageChipState, DownloadClientProbeChipState.healthy);

      await expectLater(
        controller.runStorage(() async => throw StateError('boom')),
        throwsA(isA<StateError>()),
      );
      expect(controller.storageChipState, DownloadClientProbeChipState.healthy);
      expect(controller.busy, isFalse);
    });

    test('busy 期间新的 run 直接返回 null,不并发', () async {
      final controller = DownloadClientProbeController();
      addTearDown(controller.dispose);

      final blocker = Completer<DownloadClientTestResultDto>();
      final first = controller.runConnectivity(() => blocker.future);
      // 立即再次触发:controller 已 busy,返回 null。
      final second = await controller.runConnectivity(
        () async => _connectivity(healthy: true),
      );

      expect(second, isNull);
      expect(controller.busy, isTrue);

      blocker.complete(_connectivity(healthy: true));
      await first;
      expect(controller.busy, isFalse);
    });

    test('reset 清空状态与结果', () async {
      final controller = DownloadClientProbeController();
      addTearDown(controller.dispose);

      await controller.runConnectivity(
        () async => _connectivity(healthy: false),
      );
      await controller.runStorage(
        () async => _storage(healthy: false),
      );

      expect(controller.canReplayConnectivityDialog, isTrue);
      expect(controller.canReplayStorageDialog, isTrue);

      controller.reset();

      expect(
        controller.connectivityChipState,
        DownloadClientProbeChipState.notTested,
      );
      expect(controller.storageChipState, DownloadClientProbeChipState.notTested);
      expect(controller.lastConnectivityResult, isNull);
      expect(controller.lastStorageResult, isNull);
    });

    test('applyStorageResult 回写状态并触发回调 (dialog rerun 转发路径)', () {
      DownloadClientStorageTestResultDto? emitted;
      final controller = DownloadClientProbeController(
        onStorageChanged: (result) => emitted = result,
      );
      addTearDown(controller.dispose);

      final result = _storage(healthy: true);
      controller.applyStorageResult(result);

      expect(controller.storageChipState, DownloadClientProbeChipState.healthy);
      expect(identical(controller.lastStorageResult, result), isTrue);
      expect(identical(emitted, result), isTrue);
    });

    test('用初始快照种子构造,可直接 replay 而不必先跑一次', () {
      final controller = DownloadClientProbeController(
        connectivityChipState: DownloadClientProbeChipState.unhealthy,
        connectivityResult: _connectivity(
          healthy: false,
          errorType: 'oops',
          errorMessage: 'seed',
        ),
      );
      addTearDown(controller.dispose);

      expect(controller.canReplayConnectivityDialog, isTrue);
      expect(controller.connectivityChipDetail(), '异常');
    });

    test('probeChipDetail 顶级 helper: 0ms 或 null 不展示耗时', () {
      expect(
        probeChipDetail(DownloadClientProbeChipState.healthy, elapsedMs: 0),
        isNull,
      );
      expect(
        probeChipDetail(DownloadClientProbeChipState.healthy, elapsedMs: null),
        isNull,
      );
      expect(
        probeChipDetail(DownloadClientProbeChipState.healthy, elapsedMs: 15),
        '15ms',
      );
      expect(
        probeChipDetail(DownloadClientProbeChipState.notTested),
        isNull,
      );
      expect(
        probeChipDetail(DownloadClientProbeChipState.probing),
        isNull,
      );
      expect(
        probeChipDetail(DownloadClientProbeChipState.warning),
        '有警告',
      );
      expect(
        probeChipDetail(DownloadClientProbeChipState.unhealthy),
        '异常',
      );
    });
  });
}
