import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_action_row.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_dismiss_controller.dart';

/// 装进 [showAppBottomDrawer] 的表单外壳。
///
/// 承担多个 mobile 编辑抽屉共有的外壳结构：可滚动的标题/副标题/[body]，以及
/// 常驻的 Cancel/Submit 双按钮。键盘 inset 由抽屉外壳层统一兜底。
///
/// [body] 由调用方组装 —— 通常是 FormFields，也可以在其后追加页面所需的
/// 校验提示或其他局部控件。
class AppBottomFormSheet extends StatefulWidget {
  const AppBottomFormSheet({
    super.key,
    required this.formKey,
    required this.title,
    this.subtitle,
    required this.body,
    required this.submitKey,
    required this.isSubmitting,
    required this.onSubmit,
    this.cancelLabel,
    this.submitLabel,
    this.submitDisabled = false,
    this.dismissController,
  });

  final GlobalKey<FormState> formKey;
  final String title;
  final String? subtitle;

  /// 表单主体：一般是 FormFields；可在其内部自行追加探针 chips 等附加控件。
  final Widget body;

  /// 提交按钮 Key —— 必填，测试用。
  final Key submitKey;

  final String? cancelLabel;
  final String? submitLabel;

  /// 驱动提交按钮的 spinner。同时会禁用取消按钮防误关。
  final bool isSubmitting;

  /// 独立门控：即使 `!isSubmitting` 也可让提交禁用（如探针检测进行中）。
  final bool submitDisabled;

  final VoidCallback onSubmit;

  /// 与承载抽屉共享的 dismiss controller；传入后提交状态会同步锁定弹层。
  final AppModalDismissController? dismissController;

  @override
  State<AppBottomFormSheet> createState() => _AppBottomFormSheetState();
}

class _AppBottomFormSheetState extends State<AppBottomFormSheet> {
  AppModalDismissController? _dismissController;
  bool _ownsDismissController = false;

  @override
  void initState() {
    super.initState();
    _bindDismissController();
  }

  @override
  void didUpdateWidget(covariant AppBottomFormSheet oldWidget) {
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
    final busy = widget.isSubmitting || widget.submitDisabled;
    final resolvedSubtitle = widget.subtitle;

    return AppModalDismissScope(
      controller: _dismissController!,
      child: Form(
        key: widget.formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.title,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s16,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    if (resolvedSubtitle != null) ...[
                      SizedBox(height: spacing.xs),
                      Text(
                        resolvedSubtitle,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          weight: AppTextWeight.regular,
                          tone: AppTextTone.secondary,
                        ),
                      ),
                    ],
                    SizedBox(height: spacing.lg),
                    widget.body,
                    SizedBox(height: spacing.lg),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: spacing.md),
              child: AppModalActionRow(
                cancelLabel: widget.cancelLabel ?? l10n.commonCancel,
                submitLabel: widget.submitLabel ?? l10n.commonSave,
                cancelKey: null,
                submitKey: widget.submitKey,
                isSubmitting: widget.isSubmitting,
                submitDisabled: busy,
                onCancel: busy ? null : () => Navigator.of(context).pop(),
                onSubmit: widget.onSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
