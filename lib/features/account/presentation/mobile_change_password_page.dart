import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

class MobileChangePasswordPage extends StatefulWidget {
  const MobileChangePasswordPage({super.key});

  @override
  State<MobileChangePasswordPage> createState() =>
      _MobileChangePasswordPageState();
}

class _MobileChangePasswordPageState extends State<MobileChangePasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  late final FocusNode _currentPasswordFocusNode;
  late final FocusNode _newPasswordFocusNode;
  late final FocusNode _confirmPasswordFocusNode;

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _hasAttemptedSubmit = false;
  bool _isSubmitting = false;

  AutovalidateMode get _autovalidateMode =>
      _hasAttemptedSubmit
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _currentPasswordFocusNode = FocusNode();
    _newPasswordFocusNode = FocusNode();
    _confirmPasswordFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentPasswordFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    FocusScope.of(context).unfocus();
    if (!_hasAttemptedSubmit) {
      setState(() {
        _hasAttemptedSubmit = true;
      });
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final accountApi = context.read<AccountApi>();
      final authApi = context.read<AuthApi>();
      final username = (await accountApi.getAccount()).username.trim();

      await accountApi.changePassword(
        currentPassword: _currentPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
      );

      try {
        await authApi.login(
          username: username,
          password: _newPasswordController.text.trim(),
        );
      } catch (_) {
        if (!mounted) {
          return;
        }
        showToast('密码已修改，但新密码登录校验失败，请重新登录确认');
        return;
      }

      if (!mounted) {
        return;
      }
      showToast('密码已更新，请重新登录');
      await context.read<SessionStore>().clearSession();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(apiErrorMessage(error, fallback: '修改密码失败'));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入当前密码';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    final nextPassword = value?.trim() ?? '';
    if (nextPassword.isEmpty) {
      return '请输入新密码';
    }
    if (nextPassword == _currentPasswordController.text.trim()) {
      return '新密码不能与当前密码相同';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final confirmPassword = value?.trim() ?? '';
    if (confirmPassword.isEmpty) {
      return '请再次输入新密码';
    }
    if (confirmPassword != _newPasswordController.text.trim()) {
      return '两次输入的新密码不一致';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return ColoredBox(
      key: const Key('mobile-settings-password'),
      color: colors.surfaceCard,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                spacing.md,
                spacing.md,
                spacing.md,
                spacing.lg,
              ),
              child: Form(
                key: _formKey,
                autovalidateMode: _autovalidateMode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _NoticeCard(message: '修改密码后将立即退出当前登录，需要使用新密码重新登录。'),
                    SizedBox(height: spacing.md),
                    _FormCard(
                      children: [
                        AppTextField(
                          fieldKey: const Key('mobile-password-current-field'),
                          controller: _currentPasswordController,
                          focusNode: _currentPasswordFocusNode,
                          label: '当前密码',
                          obscureText: _obscureCurrentPassword,
                          enabled: !_isSubmitting,
                          validator: _validateCurrentPassword,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted:
                              (_) => _newPasswordFocusNode.requestFocus(),
                          suffix: _PasswordVisibilityButton(
                            key: const Key(
                              'mobile-password-current-visibility-toggle',
                            ),
                            obscureText: _obscureCurrentPassword,
                            onPressed:
                                _isSubmitting
                                    ? null
                                    : () => setState(() {
                                      _obscureCurrentPassword =
                                          !_obscureCurrentPassword;
                                    }),
                          ),
                        ),
                        SizedBox(height: spacing.md),
                        AppTextField(
                          fieldKey: const Key('mobile-password-new-field'),
                          controller: _newPasswordController,
                          focusNode: _newPasswordFocusNode,
                          label: '新密码',
                          obscureText: _obscureNewPassword,
                          enabled: !_isSubmitting,
                          validator: _validateNewPassword,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted:
                              (_) => _confirmPasswordFocusNode.requestFocus(),
                          suffix: _PasswordVisibilityButton(
                            key: const Key(
                              'mobile-password-new-visibility-toggle',
                            ),
                            obscureText: _obscureNewPassword,
                            onPressed:
                                _isSubmitting
                                    ? null
                                    : () => setState(() {
                                      _obscureNewPassword =
                                          !_obscureNewPassword;
                                    }),
                          ),
                        ),
                        SizedBox(height: spacing.md),
                        AppTextField(
                          fieldKey: const Key('mobile-password-confirm-field'),
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocusNode,
                          label: '确认新密码',
                          obscureText: _obscureConfirmPassword,
                          enabled: !_isSubmitting,
                          validator: _validateConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          suffix: _PasswordVisibilityButton(
                            key: const Key(
                              'mobile-password-confirm-visibility-toggle',
                            ),
                            obscureText: _obscureConfirmPassword,
                            onPressed:
                                _isSubmitting
                                    ? null
                                    : () => setState(() {
                                      _obscureConfirmPassword =
                                          !_obscureConfirmPassword;
                                    }),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(
              spacing.md,
              spacing.md,
              spacing.md,
              spacing.md + viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: AppButton(
                key: const Key('mobile-password-submit-button'),
                label: '确认修改',
                variant: AppButtonVariant.primary,
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;

    return Container(
      key: const Key('mobile-password-notice-card'),
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: context.appComponentTokens.iconSizeMd,
            color: Theme.of(context).colorScheme.primary,
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Text(
              message,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('mobile-password-form-card'),
      padding: EdgeInsets.all(context.appSpacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _PasswordVisibilityButton extends StatelessWidget {
  const _PasswordVisibilityButton({
    super.key,
    required this.obscureText,
    required this.onPressed,
  });

  final bool obscureText;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      key: key,
      onPressed: onPressed,
      tooltip: obscureText ? '显示密码' : '隐藏密码',
      icon: Icon(
        obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: context.appComponentTokens.iconSizeSm,
      ),
    );
  }
}
