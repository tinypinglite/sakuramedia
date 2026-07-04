import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/configuration/data/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/download_client_diagnostics_dialog.dart';

/// 下载器探针种类。同一时刻只允许一个正在跑，别的入口以此判 busy。
enum DownloadClientProbeKind { connectivity, storage }

/// 卡片/胶囊上的 detail 文案。健康显示耗时(有值时),失败显示「异常」,
/// 警告显示「有警告」,其它态返回 null(chip 只显示 label)。
///
/// 顶级函数以便无 controller 的展示组件(如移动端只读卡片胶囊)也能复用。
String? probeChipDetail(
  DownloadClientProbeChipState state, {
  int? elapsedMs,
}) {
  switch (state) {
    case DownloadClientProbeChipState.healthy:
      return (elapsedMs != null && elapsedMs > 0) ? '${elapsedMs}ms' : null;
    case DownloadClientProbeChipState.warning:
      return '有警告';
    case DownloadClientProbeChipState.unhealthy:
      return '异常';
    case DownloadClientProbeChipState.notTested:
    case DownloadClientProbeChipState.probing:
      return null;
  }
}

/// 下载器「连通性 / 目录映射」两条探针的状态机。
///
/// 独立成 controller 是为了让四个入口(桌面卡片 / 桌面编辑 dialog /
/// 移动编辑抽屉 / 移动详情抽屉)复用同一份 chip 状态、结果缓存和 detail/tooltip
/// 派生逻辑——之前四处各写一份,近 300 行拷贝、易失手不一致。
///
/// 调用方只负责:
/// - 提供 `runTest` / `runStorageTest` 闭包(卡片走 `testClient(id)`,
///   编辑面板走 `probeTestClient(payload)` —— 由调用方决定)。
/// - 通过 [applyConnectivityResult] / [applyStorageResult] 回写重跑结果
///   (dialog `onResultChanged` 转发用)。
/// - 弹详情 dialog 由调用方自己 `showDialog`,controller 不碰 `BuildContext`。
class DownloadClientProbeController extends ChangeNotifier {
  DownloadClientProbeController({
    DownloadClientProbeChipState connectivityChipState =
        DownloadClientProbeChipState.notTested,
    DownloadClientProbeChipState storageChipState =
        DownloadClientProbeChipState.notTested,
    DownloadClientTestResultDto? connectivityResult,
    DownloadClientStorageTestResultDto? storageResult,
    this.onConnectivityChanged,
    this.onStorageChanged,
  })  : _connectivityChipState = connectivityChipState,
        _storageChipState = storageChipState,
        _lastConnectivity = connectivityResult,
        _lastStorage = storageResult;

  /// 每次结果落定(初次跑完 / dialog 重跑回写)时触发,便于父层把结果同步给
  /// 兄弟组件(如移动端详情抽屉 → 卡片 snapshot)。
  final ValueChanged<DownloadClientTestResultDto>? onConnectivityChanged;
  final ValueChanged<DownloadClientStorageTestResultDto>? onStorageChanged;

  DownloadClientProbeKind? _probing;
  DownloadClientProbeChipState _connectivityChipState;
  DownloadClientProbeChipState _storageChipState;
  DownloadClientTestResultDto? _lastConnectivity;
  DownloadClientStorageTestResultDto? _lastStorage;
  bool _isDisposed = false;

  DownloadClientProbeKind? get probing => _probing;
  bool get busy => _probing != null;
  DownloadClientProbeChipState get connectivityChipState =>
      _connectivityChipState;
  DownloadClientProbeChipState get storageChipState => _storageChipState;
  DownloadClientTestResultDto? get lastConnectivityResult => _lastConnectivity;
  DownloadClientStorageTestResultDto? get lastStorageResult => _lastStorage;

  /// 已是失败/警告态且有留存结果 → 应直接看详情,不额外发请求。
  bool get canReplayConnectivityDialog =>
      _lastConnectivity != null &&
      (_connectivityChipState == DownloadClientProbeChipState.unhealthy ||
          _connectivityChipState == DownloadClientProbeChipState.warning);
  bool get canReplayStorageDialog =>
      _lastStorage != null &&
      (_storageChipState == DownloadClientProbeChipState.unhealthy ||
          _storageChipState == DownloadClientProbeChipState.warning);

  String? connectivityChipDetail() => probeChipDetail(
        _connectivityChipState,
        elapsedMs: _lastConnectivity?.elapsedMs,
      );
  String? storageChipDetail() =>
      probeChipDetail(_storageChipState, elapsedMs: _lastStorage?.elapsedMs);

  /// 桌面 hover 展示的 tooltip:附加元数据的紧凑摘要。
  String? connectivityTooltip() {
    final result = _lastConnectivity;
    if (result == null) return null;
    final parts = <String>[];
    if (result.version != null) parts.add('qBittorrent ${result.version}');
    if (result.webApiVersion != null) {
      parts.add('Web API ${result.webApiVersion}');
    }
    if (result.elapsedMs > 0) parts.add('${result.elapsedMs}ms');
    if (result.error != null && result.error!.message.isNotEmpty) {
      parts.add(result.error!.message);
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? storageTooltip() {
    final result = _lastStorage;
    if (result == null) return null;
    final parts = <String>[];
    if (result.warnings.isNotEmpty) parts.addAll(result.warnings);
    if (result.hardlink.status.isNotEmpty) {
      parts.add(
        result.hardlink.supported ? '硬链接可用' : '硬链接不可用(将回退复制)',
      );
    }
    if (result.elapsedMs > 0) parts.add('${result.elapsedMs}ms');
    if (result.directoryMapping.error != null &&
        result.directoryMapping.error!.message.isNotEmpty) {
      parts.add(result.directoryMapping.error!.message);
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// 配置字段变了(编辑保存/DTO 时间戳更新) → 老探针结果作废,回到未检测态。
  void reset() {
    if (_probing != null) return;
    _connectivityChipState = DownloadClientProbeChipState.notTested;
    _storageChipState = DownloadClientProbeChipState.notTested;
    _lastConnectivity = null;
    _lastStorage = null;
    _safeNotify();
  }

  /// dialog `onResultChanged` 转发到这里,让 chip 状态与父层订阅回调同步。
  void applyConnectivityResult(DownloadClientTestResultDto next) {
    _connectivityChipState = probeChipStateFromConnectivity(next);
    _lastConnectivity = next;
    _safeNotify();
    onConnectivityChanged?.call(next);
  }

  void applyStorageResult(DownloadClientStorageTestResultDto next) {
    _storageChipState = probeChipStateFromStorage(next);
    _lastStorage = next;
    _safeNotify();
    onStorageChanged?.call(next);
  }

  /// 跑一次连通性探针。返回结果供调用方决定是否弹详情;抛出交由调用方 toast。
  ///
  /// - 已在跑 → 直接返回 null。
  /// - 失败时 chip 回落到「有留存结果 → 该结果的态」或「未检测」,并 rethrow。
  Future<DownloadClientTestResultDto?> runConnectivity(
    Future<DownloadClientTestResultDto> Function() runTest,
  ) async {
    if (_probing != null) return null;
    _probing = DownloadClientProbeKind.connectivity;
    _connectivityChipState = DownloadClientProbeChipState.probing;
    _safeNotify();
    try {
      final result = await runTest();
      if (_isDisposed) return null;
      _probing = null;
      applyConnectivityResult(result);
      return result;
    } catch (_) {
      if (_isDisposed) rethrow;
      _probing = null;
      _connectivityChipState = _lastConnectivity == null
          ? DownloadClientProbeChipState.notTested
          : probeChipStateFromConnectivity(_lastConnectivity!);
      _safeNotify();
      rethrow;
    }
  }

  Future<DownloadClientStorageTestResultDto?> runStorage(
    Future<DownloadClientStorageTestResultDto> Function() runStorageTest,
  ) async {
    if (_probing != null) return null;
    _probing = DownloadClientProbeKind.storage;
    _storageChipState = DownloadClientProbeChipState.probing;
    _safeNotify();
    try {
      final result = await runStorageTest();
      if (_isDisposed) return null;
      _probing = null;
      applyStorageResult(result);
      return result;
    } catch (_) {
      if (_isDisposed) rethrow;
      _probing = null;
      _storageChipState = _lastStorage == null
          ? DownloadClientProbeChipState.notTested
          : probeChipStateFromStorage(_lastStorage!);
      _safeNotify();
      rethrow;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }
}
