import 'package:material_ui/material_ui.dart';

/// 表单编辑器的提交与校验状态。
///
/// 桌面端保持首屏不自动校验；移动端在首次提交后切换到
/// [AutovalidateMode.onUserInteraction]，与底部表单的历史行为一致。
mixin FormSubmitState<T extends StatefulWidget> on State<T> {
  final formKey = GlobalKey<FormState>();
  bool _hasAttemptedSubmit = false;
  bool _isSubmitting = false;

  bool get usesMobileFormValidation;

  bool get isSubmitting => _isSubmitting;

  AutovalidateMode? get autovalidateMode => usesMobileFormValidation
      ? (_hasAttemptedSubmit
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled)
      : null;

  bool validateForm() {
    if (usesMobileFormValidation) {
      FocusScope.of(context).unfocus();
      if (!_hasAttemptedSubmit) {
        setState(() => _hasAttemptedSubmit = true);
      }
    }
    return formKey.currentState?.validate() ?? false;
  }

  void setSubmitting(bool value) {
    setState(() => _isSubmitting = value);
  }
}
