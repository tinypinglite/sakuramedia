import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_dismiss_binding.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_action_row.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_dismiss_controller.dart';

/// 桌面表单弹窗的正文。
///
/// 外层由 `showAppAdaptiveModal` 提供 `AppDesktopDialog`，本组件只负责表单、
/// 标题、可滚动内容与右对齐的 Save 动作区。关闭由弹窗右上角 X 承担，
/// 不再重复提供 Cancel。
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

class _AppDesktopFormDialogState extends State<AppDesktopFormDialog>
    with AppModalDismissBinding<AppDesktopFormDialog> {
  @override
  AppModalDismissController? dismissControllerFor(
    AppDesktopFormDialog widget,
  ) => widget.dismissController;

  @override
  bool isDismissLockedFor(AppDesktopFormDialog widget) => widget.isSubmitting;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final spacing = context.appSpacing;
    final busy = widget.isSubmitting || widget.isBusy;
    return AppModalDismissScope(
      controller: boundDismissController,
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
              submitLabel: l10n.commonSave,
              submitKey: widget.submitKey,
              isSubmitting: widget.isSubmitting,
              submitDisabled: busy,
              extraAction: widget.extraAction,
              showCancel: false,
              equalWidth: false,
              onSubmit: widget.onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
