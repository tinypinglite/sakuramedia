import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/forms/app_password_field.dart';

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
      await context.logOut();
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
                    const AppNoticeCard(
                      key: Key('mobile-password-notice-card'),
                      leadingIcon: Icons.info_outline_rounded,
                      description: '修改密码后将立即退出当前登录，需要使用新密码重新登录。',
                    ),
                    SizedBox(height: spacing.md),
                    _FormCard(
                      children: [
                        AppPasswordField(
                          fieldKey: const Key('mobile-password-current-field'),
                          visibilityButtonKey: const Key(
                            'mobile-password-current-visibility-toggle',
                          ),
                          controller: _currentPasswordController,
                          focusNode: _currentPasswordFocusNode,
                          label: '当前密码',
                          enabled: !_isSubmitting,
                          validator: _validateCurrentPassword,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted:
                              (_) => _newPasswordFocusNode.requestFocus(),
                        ),
                        SizedBox(height: spacing.md),
                        AppPasswordField(
                          fieldKey: const Key('mobile-password-new-field'),
                          visibilityButtonKey: const Key(
                            'mobile-password-new-visibility-toggle',
                          ),
                          controller: _newPasswordController,
                          focusNode: _newPasswordFocusNode,
                          label: '新密码',
                          enabled: !_isSubmitting,
                          validator: _validateNewPassword,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted:
                              (_) => _confirmPasswordFocusNode.requestFocus(),
                        ),
                        SizedBox(height: spacing.md),
                        AppPasswordField(
                          fieldKey: const Key('mobile-password-confirm-field'),
                          visibilityButtonKey: const Key(
                            'mobile-password-confirm-visibility-toggle',
                          ),
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocusNode,
                          label: '确认新密码',
                          enabled: !_isSubmitting,
                          validator: _validateConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
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

