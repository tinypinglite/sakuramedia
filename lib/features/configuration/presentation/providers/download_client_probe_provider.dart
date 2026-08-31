import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/download_client_diagnostics_dialog.dart';

part 'download_client_probe_provider.g.dart';

enum DownloadClientProbeKind { connectivity, storage }

String? probeChipDetail(DownloadClientProbeChipState state, {int? elapsedMs}) {
  return switch (state) {
    DownloadClientProbeChipState.healthy =>
      elapsedMs != null && elapsedMs > 0 ? '${elapsedMs}ms' : null,
    DownloadClientProbeChipState.warning => '有警告',
    DownloadClientProbeChipState.unhealthy => '异常',
    DownloadClientProbeChipState.notTested ||
    DownloadClientProbeChipState.probing => null,
  };
}

@immutable
class DownloadClientProbeState {
  const DownloadClientProbeState({
    this.probing,
    this.connectivityChipState = DownloadClientProbeChipState.notTested,
    this.storageChipState = DownloadClientProbeChipState.notTested,
    this.connectivityResult,
    this.storageResult,
  });

  final DownloadClientProbeKind? probing;
  final DownloadClientProbeChipState connectivityChipState;
  final DownloadClientProbeChipState storageChipState;
  final DownloadClientTestResultDto? connectivityResult;
  final DownloadClientStorageTestResultDto? storageResult;

  bool get busy => probing != null;
  bool get canReplayConnectivityDialog =>
      connectivityResult != null &&
      (connectivityChipState == DownloadClientProbeChipState.unhealthy ||
          connectivityChipState == DownloadClientProbeChipState.warning);
  bool get canReplayStorageDialog =>
      storageResult != null &&
      (storageChipState == DownloadClientProbeChipState.unhealthy ||
          storageChipState == DownloadClientProbeChipState.warning);
  String? get connectivityChipDetail => probeChipDetail(
    connectivityChipState,
    elapsedMs: connectivityResult?.elapsedMs,
  );
  String? get storageChipDetail =>
      probeChipDetail(storageChipState, elapsedMs: storageResult?.elapsedMs);

  String? get connectivityTooltip {
    final result = connectivityResult;
    if (result == null) return null;
    final parts = <String>[];
    if (result.version != null) parts.add('qBittorrent ${result.version}');
    if (result.webApiVersion != null) {
      parts.add('Web API ${result.webApiVersion}');
    }
    if (result.elapsedMs > 0) parts.add('${result.elapsedMs}ms');
    if (result.error?.message.isNotEmpty ?? false) {
      parts.add(result.error!.message);
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? get storageTooltip {
    final result = storageResult;
    if (result == null) return null;
    final parts = <String>[...result.warnings];
    if (result.hardlink.status.isNotEmpty) {
      parts.add(result.hardlink.supported ? '硬链接可用' : '硬链接不可用(将回退复制)');
    }
    if (result.elapsedMs > 0) parts.add('${result.elapsedMs}ms');
    if (result.directoryMapping.error?.message.isNotEmpty ?? false) {
      parts.add(result.directoryMapping.error!.message);
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  DownloadClientProbeState copyWith({
    DownloadClientProbeKind? probing,
    bool clearProbing = false,
    DownloadClientProbeChipState? connectivityChipState,
    DownloadClientProbeChipState? storageChipState,
    DownloadClientTestResultDto? connectivityResult,
    bool clearConnectivityResult = false,
    DownloadClientStorageTestResultDto? storageResult,
    bool clearStorageResult = false,
  }) {
    return DownloadClientProbeState(
      probing: clearProbing ? null : probing ?? this.probing,
      connectivityChipState:
          connectivityChipState ?? this.connectivityChipState,
      storageChipState: storageChipState ?? this.storageChipState,
      connectivityResult:
          clearConnectivityResult
              ? null
              : connectivityResult ?? this.connectivityResult,
      storageResult:
          clearStorageResult ? null : storageResult ?? this.storageResult,
    );
  }
}

/// 按调用组件 identity 隔离的本地探针状态；请求闭包由 UI 注入，避免新增 API bridge。
@riverpod
class DownloadClientProbe extends _$DownloadClientProbe {
  var _disposed = false;

  DownloadClientProbeState get currentState => state;

  @override
  DownloadClientProbeState build(Object scope) {
    ref.onDispose(() => _disposed = true);
    return const DownloadClientProbeState();
  }

  void reset() {
    if (state.busy) return;
    state = const DownloadClientProbeState();
  }

  void applyConnectivityResult(DownloadClientTestResultDto result) {
    state = state.copyWith(
      connectivityChipState: probeChipStateFromConnectivity(result),
      connectivityResult: result,
    );
  }

  void applyStorageResult(DownloadClientStorageTestResultDto result) {
    state = state.copyWith(
      storageChipState: probeChipStateFromStorage(result),
      storageResult: result,
    );
  }

  Future<DownloadClientTestResultDto?> runConnectivity(
    Future<DownloadClientTestResultDto> Function() runTest,
  ) async {
    if (state.busy) return null;
    state = state.copyWith(
      probing: DownloadClientProbeKind.connectivity,
      connectivityChipState: DownloadClientProbeChipState.probing,
    );
    try {
      final result = await runTest();
      if (_disposed) return null;
      state = state.copyWith(clearProbing: true);
      applyConnectivityResult(result);
      return result;
    } catch (_) {
      if (_disposed) rethrow;
      final previous = state.connectivityResult;
      state = state.copyWith(
        clearProbing: true,
        connectivityChipState:
            previous == null
                ? DownloadClientProbeChipState.notTested
                : probeChipStateFromConnectivity(previous),
      );
      rethrow;
    }
  }

  Future<DownloadClientStorageTestResultDto?> runStorage(
    Future<DownloadClientStorageTestResultDto> Function() runTest,
  ) async {
    if (state.busy) return null;
    state = state.copyWith(
      probing: DownloadClientProbeKind.storage,
      storageChipState: DownloadClientProbeChipState.probing,
    );
    try {
      final result = await runTest();
      if (_disposed) return null;
      state = state.copyWith(clearProbing: true);
      applyStorageResult(result);
      return result;
    } catch (_) {
      if (_disposed) rethrow;
      final previous = state.storageResult;
      state = state.copyWith(
        clearProbing: true,
        storageChipState:
            previous == null
                ? DownloadClientProbeChipState.notTested
                : probeChipStateFromStorage(previous),
      );
      rethrow;
    }
  }
}
