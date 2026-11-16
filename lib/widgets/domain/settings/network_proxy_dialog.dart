import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/providers/network_proxy_providers.dart';
import 'package:sakuramedia/core/network/network_proxy.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_action_row.dart';

/// 打开全局 HTTP 代理设置：桌面弹窗 / 移动底部抽屉。
Future<void> showNetworkProxyDialog(BuildContext context) {
  return showAppAdaptiveModal<void>(
    context: context,
    modalKey: const Key('network-proxy-dialog'),
    drawerKey: const Key('network-proxy-sheet'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    mobileMaxHeightFactor: 0.45,
    builder: (_) => const NetworkProxyDialog(),
  );
}

/// 全局 HTTP 代理地址编辑；空输入保存表示清除代理。
class NetworkProxyDialog extends ConsumerStatefulWidget {
  const NetworkProxyDialog({super.key});

  @override
  ConsumerState<NetworkProxyDialog> createState() => _NetworkProxyDialogState();
}

class _NetworkProxyDialogState extends ConsumerState<NetworkProxyDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    final config = ref.read(networkProxyControllerProvider);
    _addressController = TextEditingController(
      text: config?.displayAddress ?? '',
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final raw = _addressController.text.trim();
    final controller = ref.read(networkProxyControllerProvider.notifier);
    if (raw.isEmpty) {
      await controller.clear();
    } else {
      final config = parseNetworkProxyAddress(raw);
      if (config == null) {
        return;
      }
      await controller.save(config);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final isDrawer = AppAdaptiveModalShellScope.maybeIsDrawer(context);
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.networkProxyTitle,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s16,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            SizedBox(height: spacing.md),
            AppTextField(
              fieldKey: const Key('network-proxy-field'),
              controller: _addressController,
              label: l10n.networkProxyAddressLabel,
              hintText: l10n.networkProxyAddressHint,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                final raw = value?.trim() ?? '';
                if (raw.isEmpty) {
                  return null;
                }
                return parseNetworkProxyAddress(raw) == null
                    ? l10n.networkProxyInvalidAddress
                    : null;
              },
            ),
            SizedBox(height: spacing.lg),
            AppModalActionRow(
              cancelKey: const Key('network-proxy-cancel-button'),
              submitKey: const Key('network-proxy-save-button'),
              submitLabel: l10n.commonSave,
              equalWidth: isDrawer,
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
