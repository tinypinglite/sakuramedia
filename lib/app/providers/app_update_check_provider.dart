import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/features/status/presentation/providers/status_api_provider.dart';

/// 版本更新检查结果：客户端 / 服务端各自的最新可用版本（无更新为 null）。
@immutable
class AppUpdateCheckState {
  const AppUpdateCheckState({
    this.frontendUpdateVersion,
    this.backendUpdateVersion,
  });

  static const AppUpdateCheckState initial = AppUpdateCheckState();

  final String? frontendUpdateVersion;
  final String? backendUpdateVersion;

  bool get hasFrontendUpdate => frontendUpdateVersion != null;
  bool get hasBackendUpdate => backendUpdateVersion != null;
}

/// 版本更新检查：每小时轮询一次，失败静默（单项失败保留上一次结果）。
///
/// 桌面侧栏与移动抽屉共用这一份状态，避免两处各写一份 Timer + 检查流程。
///
/// keepAlive（手写 `NotifierProvider` 默认不自动释放）：桌面侧栏常驻所以
/// 一直有监听者；移动端首次打开抽屉时创建并首查，之后状态与轮询跨抽屉
/// 开关保留。不要改成 autoDispose——那会让移动端每次开抽屉都重跑全量
/// 检查并清空「有更新」标记。
class AppUpdateCheck extends Notifier<AppUpdateCheckState> {
  bool _isChecking = false;

  @override
  AppUpdateCheckState build() {
    final timer = Timer.periodic(const Duration(hours: 1), (_) {
      unawaited(check());
    });
    ref.onDispose(timer.cancel);
    // 首帧后检查：避免 build 期间读 pluginsProvider 触发依赖的初始化顺序问题。
    scheduleMicrotask(check);
    return AppUpdateCheckState.initial;
  }

  Future<void> check() async {
    if (_isChecking) {
      return;
    }
    _isChecking = true;
    try {
      await ref.read(appVersionInfoProvider.notifier).load();
      if (!ref.mounted) {
        return;
      }
      final frontendVersion =
          ref.read(appVersionInfoProvider).value?.frontendVersion ?? '';
      final backendVersion =
          ref.read(appVersionInfoProvider).value?.backendVersion ?? '';
      final statusApi = ref.read(statusApiProvider);
      var frontendUpdate = state.frontendUpdateVersion;
      var backendUpdate = state.backendUpdateVersion;
      if (frontendVersion.isNotEmpty) {
        try {
          frontendUpdate = await statusApi.checkFrontendUpdate(frontendVersion);
        } catch (_) {
          // 静默：保留上一次结果，不因一次失败清空「有更新」标记。
        }
      }
      if (backendVersion.isNotEmpty) {
        try {
          backendUpdate = await statusApi.checkBackendUpdate(backendVersion);
        } catch (_) {}
      }
      if (!ref.mounted) {
        return;
      }
      if (frontendUpdate != state.frontendUpdateVersion ||
          backendUpdate != state.backendUpdateVersion) {
        state = AppUpdateCheckState(
          frontendUpdateVersion: frontendUpdate,
          backendUpdateVersion: backendUpdate,
        );
      }

      try {
        final plugins = ref.read(pluginsProvider);
        final notifier = ref.read(pluginsProvider.notifier);
        if (plugins.hasError) {
          await notifier.reload();
        } else {
          await ref.read(pluginsProvider.future);
        }
        await notifier.checkUpdates();
      } catch (_) {}
    } finally {
      _isChecking = false;
    }
  }
}

final appUpdateCheckProvider =
    NotifierProvider<AppUpdateCheck, AppUpdateCheckState>(AppUpdateCheck.new);
