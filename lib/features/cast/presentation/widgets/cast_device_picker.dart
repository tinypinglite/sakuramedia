import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/cast/data/cast_device.dart';
import 'package:sakuramedia/features/cast/data/cast_director.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 打开投屏设备选择弹层（移动端底部抽屉 / 桌面端居中弹窗）。
///
/// 弹层使用固定高度：设备数量/扫描状态的切换不改变外框尺寸，避免高度跳变；
/// 列表在固定高度内滚动。
///
/// [onCast] 由弹层触发并把错误留在弹层内展示；返回成功投送的设备，
/// 取消或未投送时返回 null。
Future<CastDevice?> showCastDevicePicker({
  required BuildContext context,
  required Future<void> Function(CastDevice device) onCast,
  CastDirector? director,
}) {
  return showAppAdaptiveModal<CastDevice>(
    context: context,
    desktopWidth: 420,
    desktopHeight: 340,
    mobileHeightFactor: 0.4,
    builder: (_) => CastDevicePickerBody(
      onCast: onCast,
      director:
          director ?? CastDirector(l10n: () => AppLocalizations.of(context)),
    ),
  );
}

class CastDevicePickerBody extends StatefulWidget {
  const CastDevicePickerBody({
    super.key,
    required this.onCast,
    required this.director,
  });

  final Future<void> Function(CastDevice device) onCast;
  final CastDirector director;

  @override
  State<CastDevicePickerBody> createState() => _CastDevicePickerBodyState();
}

class _CastDevicePickerBodyState extends State<CastDevicePickerBody> {
  StreamSubscription<CastDevice>? _subscription;
  final List<CastDevice> _devices = [];
  bool _scanning = false;
  bool _scanFailed = false;
  String? _castingDeviceId;
  String? _failedDeviceId;
  String? _castErrorMessage;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _startScan() {
    unawaited(_subscription?.cancel());
    setState(() {
      _devices.clear();
      _scanning = true;
      _scanFailed = false;
      _castingDeviceId = null;
      _failedDeviceId = null;
      _castErrorMessage = null;
    });
    _subscription = widget.director.discover().listen(
      (device) {
        if (mounted) {
          setState(() => _devices.add(device));
        }
      },
      onError: (Object _) {
        if (mounted) {
          setState(() => _scanFailed = true);
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _scanning = false);
        }
      },
    );
  }

  Future<void> _cast(CastDevice device) async {
    setState(() {
      _castingDeviceId = device.id;
      _failedDeviceId = null;
      _castErrorMessage = null;
    });
    try {
      await widget.onCast(device);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(device);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _castingDeviceId = null;
        _failedDeviceId = device.id;
        _castErrorMessage = castErrorMessage(
          error,
          l10n: AppLocalizations.of(context),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.castPickerTitle,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s16,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
            ),
            // 弹窗形态右上角有浮动的关闭按钮，给「重新搜索」留出避让间距。
            if (!AppAdaptiveModalShellScope.maybeIsDrawer(context))
              SizedBox(width: spacing.xl),
            AppTextButton(
              key: const Key('cast-rescan'),
              label: l10n.castRescan,
              size: AppTextButtonSize.small,
              onPressed: _scanning ? null : _startScan,
            ),
          ],
        ),
        SizedBox(height: spacing.md),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_devices.isEmpty) {
      if (_scanFailed) {
        return AppEmptyState(
          icon: Icons.wifi_off_rounded,
          title: l10n.castSearchFailedTitle,
          message: l10n.castSearchFailedMessage,
        );
      }
      if (_scanning) {
        // 骨架占位：用接近真实列表的 3 行占位设备撑住弹层高度，
        // 避免「扫描中 → 有结果」之间的高度跳变。
        return AppSkeletonizer(
          child: AppSettingsGroup(
            children: [
              AppSettingCell(
                key: const Key('cast-scanning'),
                icon: Icons.tv_rounded,
                title: l10n.castScanningTitle,
                subtitle: l10n.castScanningSubtitle,
              ),
              AppSettingCell(
                icon: Icons.tv_rounded,
                title: l10n.castDeviceNamePlaceholder,
                subtitle: '192.168.1.100',
              ),
              AppSettingCell(
                icon: Icons.tv_rounded,
                title: l10n.castDeviceNamePlaceholder,
                subtitle: '192.168.1.101',
              ),
            ],
          ),
        );
      }
      return AppEmptyState(
        icon: Icons.tv_off_rounded,
        title: l10n.castNoDeviceTitle,
        message: l10n.castNoDeviceMessage,
      );
    }
    return SingleChildScrollView(
      child: AppSettingsGroup(children: _buildDeviceRows(context)),
    );
  }

  List<Widget> _buildDeviceRows(BuildContext context) {
    final spacing = context.appSpacing;
    final rows = <Widget>[];
    for (final device in _devices) {
      final isCasting = _castingDeviceId == device.id;
      rows.add(
        AppSettingCell(
          key: Key('cast-device-${device.id}'),
          icon: Icons.tv_rounded,
          title: device.name,
          subtitle: device.address,
          trailing: isCasting ? const AppInlineSpinner() : null,
          onTap: _castingDeviceId != null
              ? null
              : () => unawaited(_cast(device)),
        ),
      );
      if (_failedDeviceId == device.id && _castErrorMessage != null) {
        rows.add(
          Padding(
            padding: EdgeInsets.fromLTRB(spacing.lg, 0, spacing.lg, spacing.md),
            child: Text(
              _castErrorMessage!,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.error,
              ),
            ),
          ),
        );
      }
    }
    return rows;
  }
}
