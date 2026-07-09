import 'package:flutter/widgets.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/controllers/download_client_probe_controller.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/download_client_diagnostics_dialog.dart';

/// 处理「连通性」chip tap:忙碌互斥 → 可 replay 则打开详情 → 否则跑 runTest →
/// 非健康态则打开首次详情;runTest 抛异常统一 toast。
///
/// 四个入口(桌面卡片 / 桌面 dialog / 移动编辑抽屉 / 移动详情抽屉)共用同一份
/// 状态机流程,只是 [runTest] 闭包(用 id 或 payload) + [openDialog] 闭包
/// (rerun 用什么、要不要 baseUrl)不同。
Future<void> handleProbeConnectivityTap({
  required BuildContext context,
  required DownloadClientProbeController probe,
  required Future<DownloadClientTestResultDto> Function() runTest,
  required Future<void> Function(DownloadClientTestResultDto result) openDialog,
}) async {
  if (probe.busy) return;
  if (probe.canReplayConnectivityDialog) {
    await openDialog(probe.lastConnectivityResult!);
    return;
  }
  try {
    final result = await probe.runConnectivity(runTest);
    if (!context.mounted || result == null) return;
    if (probe.connectivityChipState != DownloadClientProbeChipState.healthy) {
      await openDialog(result);
    }
  } catch (error) {
    if (!context.mounted) return;
    showToast(apiErrorMessage(error, fallback: '连通性检测请求失败'));
  }
}

/// 处理「目录映射」chip tap;流程与 [handleProbeConnectivityTap] 对称,读写
/// 走 storage 那条槽位。
Future<void> handleProbeStorageTap({
  required BuildContext context,
  required DownloadClientProbeController probe,
  required Future<DownloadClientStorageTestResultDto> Function() runTest,
  required Future<void> Function(DownloadClientStorageTestResultDto result)
  openDialog,
}) async {
  if (probe.busy) return;
  if (probe.canReplayStorageDialog) {
    await openDialog(probe.lastStorageResult!);
    return;
  }
  try {
    final result = await probe.runStorage(runTest);
    if (!context.mounted || result == null) return;
    if (probe.storageChipState != DownloadClientProbeChipState.healthy) {
      await openDialog(result);
    }
  } catch (error) {
    if (!context.mounted) return;
    showToast(apiErrorMessage(error, fallback: '目录映射检测请求失败'));
  }
}
