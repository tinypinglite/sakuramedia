import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_action_row.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_dismiss_controller.dart';

/// 桌面表单弹窗的正文。
///
/// 外层由 `showAppAdaptiveModal` 提供 `AppDesktopDialog`，本组件只负责表单、
/// 标题、可滚动内容与常驻的 Cancel/Save 动作区。
class AppDesktopFormDialog extends StatefulWidget {
  const AppDesktopFormDialog({
    super.key,
    required this.formKey,
    required this.title,
    required this.body,
    required this.onSubmit,
    this.submitKey,
    this.isSubmitting = false,
    this.isBusy = false,
    this.extraAction,
    this.dismissController,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final Widget body;
  final VoidCallback? onSubmit;
  final Key? submitKey;
  final bool isSubmitting;
  final bool isBusy;

  /// 追加在 Save 后的操作，例如下载器配置测试。
  final Widget? extraAction;

  /// 与承载弹窗共享的 dismiss controller；传入后提交状态会同步锁定弹层。
  final AppModalDismissController? dismissController;

  @override
  State<AppDesktopFormDialog> createState() => _AppDesktopFormDialogState();
}

class _AppDesktopFormDialogState extends State<AppDesktopFormDialog> {
  AppModalDismissController? _dismissController;
  bool _ownsDismissController = false;

  @override
  void initState() {
    super.initState();
    _bindDismissController();
  }

  @override
  void didUpdateWidget(covariant AppDesktopFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.dismissController, widget.dismissController)) {
      _releaseDismissController();
      _bindDismissController();
    } else if (oldWidget.isSubmitting != widget.isSubmitting) {
      _dismissController?.setLocked(widget.isSubmitting);
    }
  }

  @override
  void dispose() {
    _releaseDismissController();
    super.dispose();
  }

  void _bindDismissController() {
    final supplied = widget.dismissController;
    _ownsDismissController = supplied == null;
    _dismissController = supplied ?? AppModalDismissController();
    _dismissController!.setLocked(widget.isSubmitting);
  }

  void _releaseDismissController() {
    final controller = _dismissController;
    if (controller == null) {
      return;
    }
    controller.setLocked(false);
    if (_ownsDismissController) {
      controller.dispose();
    }
    _dismissController = null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final spacing = context.appSpacing;
    final busy = widget.isSubmitting || widget.isBusy;
    return AppModalDismissScope(
      controller: _dismissController!,
      child: Form(
        key: widget.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s18,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            SizedBox(height: spacing.xl),
            Flexible(child: SingleChildScrollView(child: widget.body)),
            SizedBox(height: spacing.xl),
            AppModalActionRow(
              cancelLabel: l10n.commonCancel,
              submitLabel: l10n.commonSave,
              submitKey: widget.submitKey,
              isSubmitting: widget.isSubmitting,
              submitDisabled: busy,
              extraAction: widget.extraAction,
              onCancel: busy ? null : () => Navigator.of(context).pop(),
              onSubmit: widget.onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
