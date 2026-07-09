import 'package:flutter/material.dart';
import 'package:sakuramedia/features/configuration/data/dto/download_client_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/forms/app_info_pill.dart';

/// 下载器卡片上的探针状态胶囊状态机。
/// - [notTested]:从未点过,ghost 观感,点击运行探针
/// - [probing]:正在测,内嵌 spinner,禁用点击
/// - [healthy]:成功,绿色 tone;不弹窗
/// - [warning]:业务健康但带 warnings(仅存储探针),橙色 tone;首次自动弹一次详情
/// - [unhealthy]:失败,红色 tone;首次自动弹一次详情
enum DownloadClientProbeChipState { notTested, probing, healthy, warning, unhealthy }

DownloadClientProbeChipState probeChipStateFromConnectivity(
  DownloadClientTestResultDto result,
) {
  return result.healthy
      ? DownloadClientProbeChipState.healthy
      : DownloadClientProbeChipState.unhealthy;
}

DownloadClientProbeChipState probeChipStateFromStorage(
  DownloadClientStorageTestResultDto result,
) {
  if (!result.healthy) return DownloadClientProbeChipState.unhealthy;
  if (result.warnings.isNotEmpty) return DownloadClientProbeChipState.warning;
  return DownloadClientProbeChipState.healthy;
}

/// 卡片行上的紧凑状态胶囊:action + state 二合一。
/// - `notTested`/`healthy` 态点击运行 [onTap] (即启动新一次探针)
/// - `warning`/`unhealthy` 态点击调 [onTap] 打开详情 dialog(由调用方决定)
/// - `probing` 态自动禁用
/// - 桌面 hover 有 [tooltip] 显示附加元数据
class DownloadClientProbeStatusChip extends StatelessWidget {
  const DownloadClientProbeStatusChip({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
    this.detail,
    this.tooltip,
  });

  final String label;
  final DownloadClientProbeChipState state;
  final VoidCallback? onTap;
  final String? detail;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final palette = _resolvePalette(context, state);
    final disabled = state == DownloadClientProbeChipState.probing;

    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: context.appRadius.smBorder,
        border:
            palette.borderColor == null
                ? null
                : Border.all(color: palette.borderColor!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == DownloadClientProbeChipState.probing)
            SizedBox(
              width: context.appComponentTokens.iconSize2xs,
              height: context.appComponentTokens.iconSize2xs,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: palette.foreground,
              ),
            )
          else
            Icon(
              palette.icon,
              size: context.appComponentTokens.iconSize2xs,
              color: palette.foreground,
            ),
          SizedBox(width: spacing.xs),
          Text(
            label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.medium,
              tone: palette.tone,
            ),
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            SizedBox(width: spacing.xs),
            Text(
              detail!,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: palette.tone,
              ),
            ),
          ],
        ],
      ),
    );

    final tap = disabled ? null : onTap;
    // onTap 为 null(只读态)时用 IgnorePointer,让上层 InkWell/GestureDetector
    // 接管点击 —— 移动卡片场景下整卡都可点开详情抽屉。
    final Widget interactive =
        tap == null
            ? IgnorePointer(child: content)
            : MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: tap,
                child: content,
              ),
            );

    if (tooltip == null || tooltip!.isEmpty) return interactive;
    return Tooltip(message: tooltip!, child: interactive);
  }

  _ChipPalette _resolvePalette(
    BuildContext context,
    DownloadClientProbeChipState state,
  ) {
    final colors = context.appColors;
    switch (state) {
      case DownloadClientProbeChipState.notTested:
        return _ChipPalette(
          background: colors.surfaceMuted,
          borderColor: colors.borderSubtle,
          tone: AppTextTone.secondary,
          foreground: context.appTextPalette.secondary,
          icon: Icons.radio_button_unchecked,
        );
      case DownloadClientProbeChipState.probing:
        return _ChipPalette(
          background: colors.surfaceMuted,
          borderColor: colors.borderSubtle,
          tone: AppTextTone.secondary,
          foreground: context.appTextPalette.secondary,
          icon: Icons.hourglass_top,
        );
      case DownloadClientProbeChipState.healthy:
        return _ChipPalette(
          background: colors.successSurface,
          borderColor: null,
          tone: AppTextTone.success,
          foreground: resolveAppTextToneColor(context, AppTextTone.success),
          icon: Icons.check_circle_outline,
        );
      case DownloadClientProbeChipState.warning:
        return _ChipPalette(
          background: colors.warningSurface,
          borderColor: null,
          tone: AppTextTone.warning,
          foreground: resolveAppTextToneColor(context, AppTextTone.warning),
          icon: Icons.warning_amber_rounded,
        );
      case DownloadClientProbeChipState.unhealthy:
        return _ChipPalette(
          background: colors.errorSurface,
          borderColor: null,
          tone: AppTextTone.error,
          foreground: resolveAppTextToneColor(context, AppTextTone.error),
          icon: Icons.error_outline,
        );
    }
  }
}

class _ChipPalette {
  const _ChipPalette({
    required this.background,
    required this.borderColor,
    required this.tone,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color? borderColor;
  final AppTextTone tone;
  final Color foreground;
  final IconData icon;
}

/// 连通性检测结果对话框。
///
/// 只做展示；HTTP 层异常在调用方 toast，进这里的 result 都是拿到 body 的正常态
/// (包括 `healthy=false` 的业务失败)。
class DownloadClientTestResultDialog extends StatefulWidget {
  const DownloadClientTestResultDialog({
    super.key,
    required this.initialResult,
    required this.onRerun,
    this.onResultChanged,
  });

  final DownloadClientTestResultDto initialResult;
  final Future<DownloadClientTestResultDto> Function() onRerun;

  /// 重跑成功后回调,让打开该 dialog 的卡片同步更新胶囊状态。
  final ValueChanged<DownloadClientTestResultDto>? onResultChanged;

  @override
  State<DownloadClientTestResultDialog> createState() =>
      _DownloadClientTestResultDialogState();
}

class _DownloadClientTestResultDialogState
    extends State<DownloadClientTestResultDialog> {
  late DownloadClientTestResultDto _result = widget.initialResult;
  bool _rerunning = false;

  Future<void> _rerun() async {
    setState(() => _rerunning = true);
    try {
      final next = await widget.onRerun();
      if (!mounted) return;
      setState(() {
        _result = next;
        _rerunning = false;
      });
      widget.onResultChanged?.call(next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _rerunning = false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AppDesktopDialog(
      dialogKey: const Key('download-client-diagnostics-dialog'),
      width: context.appLayoutTokens.dialogWidthMd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DiagnosticsHeader(
            title: '连通性检测',
            subtitle: '${_result.clientName} · ${_result.baseUrl}',
            healthy: _result.healthy,
            elapsedMs: _result.elapsedMs,
          ),
          SizedBox(height: spacing.xl),
          if (_result.error != null)
            _DiagnosticsErrorCard(error: _result.error!)
          else
            AppSettingsGroup(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.lg,
                    vertical: spacing.md,
                  ),
                  child: Wrap(
                    spacing: spacing.md,
                    runSpacing: spacing.sm,
                    children: [
                      AppInfoPill(
                        label: 'qBittorrent 版本',
                        value: _result.version ?? '未知',
                      ),
                      AppInfoPill(
                        label: 'Web API 版本',
                        value: _result.webApiVersion ?? '未知',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          SizedBox(height: spacing.xl),
          _DiagnosticsFooter(
            rerunning: _rerunning,
            onRerun: _rerun,
            onClose: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// 目录映射 + 硬链接检测结果对话框。
class DownloadClientStorageTestResultDialog extends StatefulWidget {
  const DownloadClientStorageTestResultDialog({
    super.key,
    required this.initialResult,
    required this.clientBaseUrl,
    required this.onRerun,
    this.onResultChanged,
  });

  final DownloadClientStorageTestResultDto initialResult;
  final String clientBaseUrl;
  final Future<DownloadClientStorageTestResultDto> Function() onRerun;

  /// 重跑成功后回调,让打开该 dialog 的卡片同步更新胶囊状态。
  final ValueChanged<DownloadClientStorageTestResultDto>? onResultChanged;

  @override
  State<DownloadClientStorageTestResultDialog> createState() =>
      _DownloadClientStorageTestResultDialogState();
}

class _DownloadClientStorageTestResultDialogState
    extends State<DownloadClientStorageTestResultDialog> {
  late DownloadClientStorageTestResultDto _result = widget.initialResult;
  bool _rerunning = false;

  Future<void> _rerun() async {
    setState(() => _rerunning = true);
    try {
      final next = await widget.onRerun();
      if (!mounted) return;
      setState(() {
        _result = next;
        _rerunning = false;
      });
      widget.onResultChanged?.call(next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _rerunning = false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final mapping = _result.directoryMapping;
    final hardlink = _result.hardlink;

    return AppDesktopDialog(
      dialogKey: const Key('download-client-diagnostics-dialog'),
      width: context.appLayoutTokens.dialogWidthMd,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DiagnosticsHeader(
              title: '目录映射检测',
              subtitle: '${_result.clientName} · ${widget.clientBaseUrl}',
              healthy: _result.healthy,
              elapsedMs: _result.elapsedMs,
            ),
            SizedBox(height: spacing.xl),
            if (_result.warnings.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: spacing.lg),
                child: _DiagnosticsWarningsBanner(warnings: _result.warnings),
              ),
            _DiagnosticsSectionTitle(title: '目录映射'),
            SizedBox(height: spacing.sm),
            AppSettingsGroup(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.lg,
                    vertical: spacing.md,
                  ),
                  child: Wrap(
                    spacing: spacing.md,
                    runSpacing: spacing.sm,
                    children: [
                      _StatusPill(
                        label: '映射状态',
                        status: mapping.status,
                        goodValues: const <String>{'ok'},
                      ),
                      AppInfoPill(
                        label: 'qBittorrent 保存路径',
                        value: mapping.clientSavePath,
                      ),
                      AppInfoPill(
                        label: '本地访问路径',
                        value: mapping.localRootPath,
                      ),
                      AppInfoPill(
                        label: '哨兵目录 (qB 视角)',
                        value: mapping.probeRemoteDir,
                      ),
                      AppInfoPill(
                        label: '哨兵目录 (后端视角)',
                        value: mapping.probeLocalDir,
                      ),
                      _BooleanPill(
                        label: 'qB 能看到哨兵文件',
                        value: mapping.sentinelVisibleToQb,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (mapping.error != null) ...[
              SizedBox(height: spacing.md),
              _DiagnosticsErrorCard(error: mapping.error!),
            ],
            SizedBox(height: spacing.lg),
            _DiagnosticsSectionTitle(title: '硬链接'),
            SizedBox(height: spacing.sm),
            AppSettingsGroup(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.lg,
                    vertical: spacing.md,
                  ),
                  child: Wrap(
                    spacing: spacing.md,
                    runSpacing: spacing.sm,
                    children: [
                      _StatusPill(
                        label: '硬链接状态',
                        status: hardlink.status,
                        goodValues: const <String>{'ok'},
                      ),
                      _BooleanPill(
                        label: '支持硬链接',
                        value: hardlink.supported,
                      ),
                      AppInfoPill(
                        label: '源文件',
                        value: hardlink.sourcePath,
                      ),
                      AppInfoPill(
                        label: '目标文件',
                        value: hardlink.targetPath,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (hardlink.error != null) ...[
              SizedBox(height: spacing.md),
              _DiagnosticsErrorCard(error: hardlink.error!),
            ],
            SizedBox(height: spacing.xl),
            _DiagnosticsFooter(
              rerunning: _rerunning,
              onRerun: _rerun,
              onClose: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsHeader extends StatelessWidget {
  const _DiagnosticsHeader({
    required this.title,
    required this.subtitle,
    required this.healthy,
    required this.elapsedMs,
  });

  final String title;
  final String subtitle;
  final bool healthy;
  final int elapsedMs;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s18,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: spacing.md),
        _HealthyBadge(healthy: healthy, elapsedMs: elapsedMs),
      ],
    );
  }
}

class _HealthyBadge extends StatelessWidget {
  const _HealthyBadge({required this.healthy, required this.elapsedMs});

  final bool healthy;
  final int elapsedMs;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final background =
        healthy
            ? context.appColors.successSurface
            : context.appColors.errorSurface;
    final tone = healthy ? AppTextTone.success : AppTextTone.error;
    final label = healthy ? '正常' : '异常';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: context.appRadius.smBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            healthy ? Icons.check_circle_outline : Icons.error_outline,
            size: context.appComponentTokens.iconSizeSm,
            color: resolveAppTextToneColor(context, tone),
          ),
          SizedBox(width: spacing.xs),
          Text(
            label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.semibold,
              tone: tone,
            ),
          ),
          SizedBox(width: spacing.sm),
          Text(
            '${elapsedMs}ms',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: tone,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsErrorCard extends StatelessWidget {
  const _DiagnosticsErrorCard({required this.error});

  final DownloadClientDiagnosticErrorDto error;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: context.appColors.errorSurface,
        borderRadius: context.appRadius.smBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            error.type.isEmpty ? '错误' : error.type,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.error,
            ),
          ),
          if (error.message.isNotEmpty) ...[
            SizedBox(height: spacing.xs),
            SelectableText(
              error.message,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiagnosticsWarningsBanner extends StatelessWidget {
  const _DiagnosticsWarningsBanner({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: context.appColors.warningSurface,
        borderRadius: context.appRadius.smBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: context.appComponentTokens.iconSizeSm,
            color: resolveAppTextToneColor(context, AppTextTone.warning),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final warning in warnings)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: spacing.xs),
                    child: Text(
                      warning,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.warning,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsSectionTitle extends StatelessWidget {
  const _DiagnosticsSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.medium,
        tone: AppTextTone.secondary,
      ),
    );
  }
}

class _DiagnosticsFooter extends StatelessWidget {
  const _DiagnosticsFooter({
    required this.rerunning,
    required this.onRerun,
    required this.onClose,
  });

  final bool rerunning;
  final Future<void> Function() onRerun;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Row(
      children: [
        Expanded(
          child: AppButton(
            key: const Key('download-client-diagnostics-rerun'),
            onPressed: rerunning ? null : () => onRerun(),
            label: '重新测试',
            isLoading: rerunning,
          ),
        ),
        SizedBox(width: spacing.md),
        Expanded(
          child: AppButton(
            onPressed: onClose,
            label: '关闭',
            variant: AppButtonVariant.primary,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.status,
    required this.goodValues,
  });

  final String label;
  final String status;
  final Set<String> goodValues;

  @override
  Widget build(BuildContext context) {
    final isGood = goodValues.contains(status);
    return AppInfoPill(
      label: label,
      value: status.isEmpty ? '未知' : (isGood ? '$status ✓' : status),
    );
  }
}

class _BooleanPill extends StatelessWidget {
  const _BooleanPill({required this.label, required this.value});

  final String label;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return AppInfoPill(label: label, value: value ? '是' : '否');
  }
}

/// 新建/编辑面板里的「保存前测试」区块:小节标题 + 连通性/目录映射两个胶囊。
///
/// 桌面 dialog 与移动抽屉共用同一份布局,通过 [keyPrefix] 区分锚点 key。
class DownloadClientEditorProbeChips extends StatelessWidget {
  const DownloadClientEditorProbeChips({
    super.key,
    required this.keyPrefix,
    required this.busy,
    required this.connectivityState,
    required this.storageState,
    required this.connectivityDetail,
    required this.storageDetail,
    required this.onConnectivityTap,
    required this.onStorageTap,
    this.sectionTitle = '保存前测试',
  });

  final String keyPrefix;
  final bool busy;
  final DownloadClientProbeChipState connectivityState;
  final DownloadClientProbeChipState storageState;
  final String? connectivityDetail;
  final String? storageDetail;
  final Future<void> Function() onConnectivityTap;
  final Future<void> Function() onStorageTap;
  final String sectionTitle;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionTitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.sm),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: [
            DownloadClientProbeStatusChip(
              key: Key('$keyPrefix-probe-test'),
              label: '连通性',
              state: connectivityState,
              detail: connectivityDetail,
              onTap: busy ? null : onConnectivityTap,
            ),
            DownloadClientProbeStatusChip(
              key: Key('$keyPrefix-probe-storage-test'),
              label: '目录映射',
              state: storageState,
              detail: storageDetail,
              onTap: busy ? null : onStorageTap,
            ),
          ],
        ),
      ],
    );
  }
}
