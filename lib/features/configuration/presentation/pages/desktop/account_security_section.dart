import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/account/presentation/providers/account_api_provider.dart';
import 'package:sakuramedia/features/auth/presentation/providers/auth_api_provider.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/account/data/account_dto.dart';
import 'package:sakuramedia/features/account/presentation/providers/account_profile_provider.dart';
import 'package:sakuramedia/features/account/presentation/providers/account_profile_state.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';
import 'package:sakuramedia/widgets/base/forms/app_password_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

class AccountSecuritySection extends ConsumerStatefulWidget {
  const AccountSecuritySection({super.key});

  @override
  ConsumerState<AccountSecuritySection> createState() =>
      _AccountSecuritySectionState();
}

class _AccountSecuritySectionState
    extends ConsumerState<AccountSecuritySection> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _profileFormKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  bool _isSubmitting = false;
  bool _hasAttemptedUsernameSubmit = false;
  bool _hasSyncedInitialUsername = false;

  @override
  void initState() {
    super.initState();
    _usernameController =
        TextEditingController()..addListener(_handleUsernameChanged);
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController
      ..removeListener(_handleUsernameChanged)
      ..dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// 首次拉到 account 后灌 username 到输入框；后续不再自动覆盖（尊重用户已改动）。
  void _syncInitialUsername(AccountProfileState state) {
    if (_hasSyncedInitialUsername) return;
    final account = state.account;
    if (account == null) return;
    _hasSyncedInitialUsername = true;
    _usernameController.text = account.username;
  }

  void _handleUsernameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submitUsername() async {
    final notifier = ref.read(accountProfileProvider.notifier);
    if (ref.read(accountProfileProvider).isSaving) {
      return;
    }

    if (!_hasAttemptedUsernameSubmit) {
      setState(() {
        _hasAttemptedUsernameSubmit = true;
      });
    }

    if (!(_profileFormKey.currentState?.validate() ?? false)) {
      return;
    }

    final saved = await notifier.saveUsername(_usernameController.text);
    if (!mounted) {
      return;
    }
    final state = ref.read(accountProfileProvider);
    if (saved) {
      _usernameController.text = state.account?.username ?? '';
      showToast('用户名已更新');
      return;
    }

    final message = state.errorMessage;
    if (message != null && message.isNotEmpty) {
      showToast(message);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final accountApi = ref.read(accountApiProvider);
      final authApi = ref.read(authApiProvider);
      final cachedAccount = ref.read(accountProfileProvider).account;
      final username =
          (cachedAccount?.username.trim().isNotEmpty ?? false)
              ? cachedAccount!.username.trim()
              : (await accountApi.getAccount()).username.trim();

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

  void _reset() {
    if (_isSubmitting) {
      return;
    }

    _formKey.currentState?.reset();
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入当前密码';
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入用户名';
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
    final profileState = ref.watch(accountProfileProvider);
    _syncInitialUsername(profileState);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAccountProfileCard(context, profileState),
        SizedBox(height: spacing.xl),
        _buildPasswordCard(context),
      ],
    );
  }

  Widget _buildAccountProfileCard(
    BuildContext context,
    AccountProfileState profileState,
  ) {
    final spacing = context.appSpacing;
    final account = profileState.account;
    final canSubmitUsername = !profileState.isLoading &&
        !profileState.isSaving &&
        account != null;

    return AppContentCard(
      title: '账号资料',
      padding: EdgeInsets.all(spacing.lg),
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s18,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      headerBottomSpacing: spacing.md,
      child: Form(
        key: _profileFormKey,
        autovalidateMode:
            _hasAttemptedUsernameSubmit
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profileState.isLoading && account == null)
              const _AccountProfileLoadingBlock()
            else if (profileState.errorMessage != null && account == null)
              _AccountProfileErrorBlock(
                message: profileState.errorMessage!,
                onRetry: () =>
                    ref.read(accountProfileProvider.notifier).load(),
              )
            else ...[
              Text(
                '用户名用于登录和账号识别，保存后当前登录态保持不变。',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
              if (account != null) ...[
                SizedBox(height: spacing.lg),
                _AccountProfileSummary(account: account),
              ],
              SizedBox(height: spacing.lg),
              AppTextField(
                fieldKey: const Key('configuration-username-field'),
                controller: _usernameController,
                label: '用户名',
                hintText: '请输入新的用户名',
                enabled: !profileState.isSaving,
                validator: _validateUsername,
              ),
              if (profileState.errorMessage != null && account != null) ...[
                SizedBox(height: spacing.sm),
                Text(
                  profileState.errorMessage!,
                  key: const Key('configuration-username-error-text'),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.error,
                  ),
                ),
              ],
              SizedBox(height: spacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: AppButton(
                  key: const Key('configuration-username-submit-button'),
                  onPressed: canSubmitUsername ? _submitUsername : null,
                  label: '保存用户名',
                  variant: AppButtonVariant.primary,
                  isLoading: profileState.isSaving,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCard(BuildContext context) {
    final spacing = context.appSpacing;

    return AppContentCard(
      title: '修改密码',
      padding: EdgeInsets.all(spacing.lg),
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s18,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      headerBottomSpacing: spacing.md,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '修改密码后将立即退出当前登录，需要使用新密码重新登录。',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.muted,
              ),
            ),
            SizedBox(height: spacing.lg),
            AppPasswordField(
              fieldKey: const Key('configuration-password-current-field'),
              controller: _currentPasswordController,
              label: '当前密码',
              validator: _validateCurrentPassword,
            ),
            SizedBox(height: spacing.lg),
            AppPasswordField(
              fieldKey: const Key('configuration-password-new-field'),
              controller: _newPasswordController,
              label: '新密码',
              validator: _validateNewPassword,
            ),
            SizedBox(height: spacing.lg),
            AppPasswordField(
              fieldKey: const Key('configuration-password-confirm-field'),
              controller: _confirmPasswordController,
              label: '确认新密码',
              validator: _validateConfirmPassword,
            ),
            SizedBox(height: spacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  key: const Key('configuration-password-reset-button'),
                  onPressed: _isSubmitting ? null : _reset,
                  label: '重置',
                ),
                SizedBox(width: spacing.md),
                AppButton(
                  key: const Key('configuration-password-submit-button'),
                  onPressed: _submit,
                  label: '修改密码',
                  variant: AppButtonVariant.primary,
                  isLoading: _isSubmitting,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountProfileLoadingBlock extends StatelessWidget {
  const _AccountProfileLoadingBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSkeletonBlock(width: double.infinity, height: 48),
        SizedBox(height: context.appSpacing.md),
        const AppSkeletonBlock(width: double.infinity, height: 44),
      ],
    );
  }
}

class _AccountProfileErrorBlock extends StatelessWidget {
  const _AccountProfileErrorBlock({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppEmptyState(message: message),
        SizedBox(height: context.appSpacing.md),
        AppButton(
          key: const Key('configuration-username-retry-button'),
          label: '重试',
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _AccountProfileSummary extends StatelessWidget {
  const _AccountProfileSummary({required this.account});

  final AccountDto account;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Wrap(
      spacing: spacing.md,
      runSpacing: spacing.sm,
      children: [
        _AccountProfilePill(label: '当前用户名', value: account.username),
        _AccountProfilePill(
          label: '创建时间',
          value: formatUpdatedAtLabel(account.createdAt) ?? '未知',
        ),
        _AccountProfilePill(
          label: '上次登录',
          value: formatUpdatedAtLabel(account.lastLoginAt) ?? '未知',
        ),
      ],
    );
  }
}

class _AccountProfilePill extends StatelessWidget {
  const _AccountProfilePill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('configuration-account-profile-$label'),
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.smBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: context.appSpacing.xs),
          Text(
            value,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.medium,
              tone: AppTextTone.primary,
            ),
          ),
        ],
      ),
    );
  }
}
