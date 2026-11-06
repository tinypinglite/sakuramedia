import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/account/data/account_dto.dart';
import 'package:sakuramedia/features/account/presentation/account_placeholders.dart';
import 'package:sakuramedia/features/account/presentation/providers/account_api_provider.dart';
import 'package:sakuramedia/features/account/presentation/providers/account_profile_provider.dart';
import 'package:sakuramedia/features/account/presentation/providers/account_profile_state.dart';
import 'package:sakuramedia/features/account/presentation/providers/api_keys_provider.dart';
import 'package:sakuramedia/features/auth/presentation/providers/auth_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/forms/app_password_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_dialog.dart';
import 'package:sakuramedia/widgets/domain/account/api_key_generate_panel.dart';

/// 账号安全设置：桌面分类页与移动子页共用业务逻辑和表单状态。
class AccountSecurityContent extends ConsumerStatefulWidget {
  const AccountSecurityContent({
    super.key,
    required this.mobile,
    this.active = true,
  });

  final bool mobile;
  final bool active;

  @override
  ConsumerState<AccountSecurityContent> createState() =>
      _AccountSecurityContentState();
}

class _AccountSecurityContentState
    extends ConsumerState<AccountSecurityContent> {
  final GlobalKey<FormState> _usernameFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _currentPasswordController;
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;

  bool _hasAttemptedUsernameSubmit = false;
  bool _hasAttemptedPasswordSubmit = false;
  bool _hasSyncedInitialUsername = false;
  bool _isSubmittingPassword = false;

  AutovalidateMode? get _usernameAutovalidateMode => widget.mobile
      ? (_hasAttemptedUsernameSubmit
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled)
      : null;

  AutovalidateMode? get _passwordAutovalidateMode => widget.mobile
      ? (_hasAttemptedPasswordSubmit
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled)
      : null;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _syncInitialUsername(AccountProfileState state) {
    if (_hasSyncedInitialUsername) return;
    final account = state.account;
    if (account == null) return;
    _hasSyncedInitialUsername = true;
    _usernameController.text = account.username;
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(accountProfileProvider);
    _syncInitialUsername(profileState);
    if (widget.mobile) return _buildMobile(context, profileState);
    final content = _buildDesktopContent(context, profileState);
    return widget.active
        ? AppPageRefreshScope(onRefresh: _refresh, child: content)
        : content;
  }

  Widget _buildMobile(BuildContext context, AccountProfileState profileState) {
    final spacing = context.appSpacing;
    return ListView(
      key: const Key('mobile-settings-account-security'),
      padding: EdgeInsets.only(
        top: spacing.md,
        bottom: spacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _buildAccountCard(context, profileState),
        SizedBox(height: spacing.xl),
        _buildPasswordCard(context),
        SizedBox(height: spacing.xl),
        _buildApiKeysCard(context),
      ],
    );
  }

  Widget _buildDesktopContent(
    BuildContext context,
    AccountProfileState profileState,
  ) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAccountCard(context, profileState),
        SizedBox(height: spacing.xl),
        _buildPasswordCard(context),
        SizedBox(height: spacing.xl),
        _buildApiKeysCard(context),
      ],
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    AccountProfileState profileState,
  ) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final account = profileState.account;
    final showSkeleton = profileState.isLoading && account == null;
    final displayAccount = showSkeleton ? accountPlaceholder() : account;
    final canSubmitUsername =
        !profileState.isLoading && !profileState.isSaving && account != null;
    return AppContentCard(
      key: widget.mobile ? const Key('mobile-account-card') : null,
      title: widget.mobile ? l10n.accountTitle : l10n.accountProfileTitle,
      padding: EdgeInsets.all(widget.mobile ? spacing.md : spacing.lg),
      headerBottomSpacing: widget.mobile ? null : spacing.md,
      child: AppSkeletonizer(
        enabled: showSkeleton,
        child: Column(
          crossAxisAlignment: widget.mobile
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: [
            if (profileState.errorMessage != null && account == null)
              _buildProfileError(context, profileState.errorMessage!)
            else ...[
              if (!widget.mobile)
                Text(
                  l10n.accountUsernameHelpDesktop,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.muted,
                  ),
                ),
              if (displayAccount != null) ...[
                SizedBox(height: widget.mobile ? 0 : spacing.lg),
                if (widget.mobile)
                  _buildMobileAccountSummary(context, displayAccount)
                else
                  _AccountProfileSummary(account: displayAccount),
              ],
              SizedBox(height: spacing.lg),
              Form(
                key: _usernameFormKey,
                autovalidateMode:
                    _usernameAutovalidateMode ?? AutovalidateMode.disabled,
                child: Column(
                  crossAxisAlignment: widget.mobile
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      fieldKey: widget.mobile
                          ? const Key('mobile-account-username-field')
                          : const Key('configuration-username-field'),
                      controller: _usernameController,
                      label: l10n.accountUsername,
                      hintText: l10n.accountUsernameHint,
                      helperText: widget.mobile
                          ? l10n.accountUsernameHelpMobile
                          : null,
                      enabled: !profileState.isSaving,
                      autovalidateMode: _usernameAutovalidateMode,
                      validator: _validateUsername,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submitUsername(),
                    ),
                    if (profileState.errorMessage != null &&
                        account != null) ...[
                      SizedBox(height: spacing.sm),
                      Text(
                        profileState.errorMessage!,
                        key: widget.mobile
                            ? const Key('mobile-account-username-error-text')
                            : const Key('configuration-username-error-text'),
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s12,
                          tone: AppTextTone.error,
                        ),
                      ),
                    ],
                    SizedBox(height: spacing.lg),
                    if (widget.mobile)
                      AppButton(
                        key: const Key('mobile-account-username-submit-button'),
                        label: l10n.accountSaveUsername,
                        variant: AppButtonVariant.primary,
                        isLoading: profileState.isSaving,
                        onPressed: canSubmitUsername ? _submitUsername : null,
                      )
                    else
                      Align(
                        alignment: Alignment.centerRight,
                        child: AppButton(
                          key: const Key(
                            'configuration-username-submit-button',
                          ),
                          onPressed: canSubmitUsername ? _submitUsername : null,
                          label: l10n.accountSaveUsername,
                          variant: AppButtonVariant.primary,
                          isLoading: profileState.isSaving,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileError(BuildContext context, String message) {
    if (!widget.mobile) {
      return _AccountProfileErrorBlock(
        message: message,
        onRetry: () => ref.read(accountProfileProvider.notifier).load(),
      );
    }
    return AppEmptyState(
      message: message,
      retryKey: const Key('mobile-account-retry-button'),
      onRetry: () => ref.read(accountProfileProvider.notifier).load(),
    );
  }

  Widget _buildMobileAccountSummary(BuildContext context, AccountDto account) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _AccountInfoRow(label: l10n.accountUsername, value: account.username),
        SizedBox(height: spacing.sm),
        _AccountInfoRow(
          label: l10n.accountCreatedAt,
          value: formatUpdatedAtLabel(account.createdAt) ?? l10n.commonUnknown,
        ),
        SizedBox(height: spacing.sm),
        _AccountInfoRow(
          label: l10n.accountLastLogin,
          value:
              formatUpdatedAtLabel(account.lastLoginAt) ?? l10n.commonUnknown,
        ),
        SizedBox(height: spacing.md),
        Divider(height: 1, color: context.appColors.divider),
      ],
    );
  }

  Future<void> _submitUsername() async {
    final notifier = ref.read(accountProfileProvider.notifier);
    if (ref.read(accountProfileProvider).isSaving) return;
    if (widget.mobile) FocusScope.of(context).unfocus();
    if (!_hasAttemptedUsernameSubmit) {
      setState(() => _hasAttemptedUsernameSubmit = true);
    }
    if (!(_usernameFormKey.currentState?.validate() ?? false)) return;
    final saved = await notifier.saveUsername(_usernameController.text);
    if (!mounted) return;
    final state = ref.read(accountProfileProvider);
    if (saved) {
      _usernameController.text = state.account?.username ?? '';
      showToast(
        AppLocalizations.of(context).accountUsernameUpdated,
        tone: AppToastTone.success,
      );
      return;
    }
    final message = state.errorMessage;
    if (message != null && message.isNotEmpty) showToast(message);
  }

  Widget _buildPasswordCard(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return AppContentCard(
      key: widget.mobile ? const Key('mobile-account-password-card') : null,
      title: l10n.accountChangePasswordTitle,
      padding: EdgeInsets.all(widget.mobile ? spacing.md : spacing.lg),
      headerBottomSpacing: widget.mobile ? null : spacing.md,
      child: Form(
        key: _passwordFormKey,
        autovalidateMode:
            _passwordAutovalidateMode ?? AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: widget.mobile
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: [
            Text(
              l10n.accountChangePasswordNotice,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.muted,
              ),
            ),
            SizedBox(height: widget.mobile ? spacing.md : spacing.lg),
            AppPasswordField(
              fieldKey: widget.mobile
                  ? const Key('mobile-account-password-current-field')
                  : const Key('configuration-password-current-field'),
              controller: _currentPasswordController,
              label: l10n.accountCurrentPassword,
              enabled: !_isSubmittingPassword,
              autovalidateMode: _passwordAutovalidateMode,
              validator: _validateCurrentPassword,
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: widget.mobile ? spacing.md : spacing.lg),
            AppPasswordField(
              fieldKey: widget.mobile
                  ? const Key('mobile-account-password-new-field')
                  : const Key('configuration-password-new-field'),
              controller: _newPasswordController,
              label: l10n.accountNewPassword,
              enabled: !_isSubmittingPassword,
              autovalidateMode: _passwordAutovalidateMode,
              validator: _validateNewPassword,
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: widget.mobile ? spacing.md : spacing.lg),
            AppPasswordField(
              fieldKey: widget.mobile
                  ? const Key('mobile-account-password-confirm-field')
                  : const Key('configuration-password-confirm-field'),
              controller: _confirmPasswordController,
              label: l10n.accountConfirmNewPassword,
              enabled: !_isSubmittingPassword,
              autovalidateMode: _passwordAutovalidateMode,
              validator: _validateConfirmPassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitPassword(),
            ),
            SizedBox(height: spacing.lg),
            if (widget.mobile)
              AppButton(
                key: const Key('mobile-account-password-submit-button'),
                label: l10n.accountConfirmChange,
                variant: AppButtonVariant.primary,
                isLoading: _isSubmittingPassword,
                onPressed: _isSubmittingPassword ? null : _submitPassword,
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    key: const Key('configuration-password-reset-button'),
                    onPressed: _isSubmittingPassword ? null : _resetPassword,
                    label: l10n.accountReset,
                  ),
                  SizedBox(width: spacing.md),
                  AppButton(
                    key: const Key('configuration-password-submit-button'),
                    onPressed: _submitPassword,
                    label: l10n.accountChangePasswordTitle,
                    variant: AppButtonVariant.primary,
                    isLoading: _isSubmittingPassword,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPassword() async {
    if (_isSubmittingPassword) return;
    if (widget.mobile) FocusScope.of(context).unfocus();
    if (!_hasAttemptedPasswordSubmit) {
      setState(() => _hasAttemptedPasswordSubmit = true);
    }
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    setState(() => _isSubmittingPassword = true);
    try {
      final accountApi = ref.read(accountApiProvider);
      final authApi = ref.read(authApiProvider);
      final cachedAccount = ref.read(accountProfileProvider).account;
      final username = (cachedAccount?.username.trim().isNotEmpty ?? false)
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
        if (!mounted) return;
        showToast(
          AppLocalizations.of(context).accountPasswordChangedReloginFailed,
          tone: AppToastTone.error,
        );
        return;
      }
      if (!mounted) return;
      showToast(
        AppLocalizations.of(context).accountPasswordChangedRelogin,
        tone: AppToastTone.success,
      );
      await context.logOut();
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.errorChangePasswordFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    } finally {
      if (mounted) setState(() => _isSubmittingPassword = false);
    }
  }

  void _resetPassword() {
    if (_isSubmittingPassword) return;
    _passwordFormKey.currentState?.reset();
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  Future<void> _refresh() async {
    if (_isSubmittingPassword || ref.read(accountProfileProvider).isSaving) {
      return;
    }
    await ref.read(accountProfileProvider.notifier).load();
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context).errorUsernameRequired;
    }
    return null;
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context).accountCurrentPasswordRequired;
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    final nextPassword = value?.trim() ?? '';
    if (nextPassword.isEmpty) {
      return AppLocalizations.of(context).accountNewPasswordRequired;
    }
    if (nextPassword == _currentPasswordController.text.trim()) {
      return AppLocalizations.of(context).accountNewPasswordSameAsCurrent;
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final confirmPassword = value?.trim() ?? '';
    if (confirmPassword.isEmpty) {
      return AppLocalizations.of(context).accountConfirmPasswordRequired;
    }
    if (confirmPassword != _newPasswordController.text.trim()) {
      return AppLocalizations.of(context).accountPasswordMismatch;
    }
    return null;
  }

  Widget _buildApiKeysCard(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final asyncKeys = ref.watch(apiKeysProvider);
    final keys = asyncKeys.value ?? const <ApiKeyDto>[];
    final showInitialLoading = asyncKeys.isLoading && !asyncKeys.hasValue;
    return AppContentCard(
      key: widget.mobile ? const Key('mobile-account-apikeys-card') : null,
      title: l10n.apiKeysTitle,
      padding: EdgeInsets.all(widget.mobile ? spacing.md : spacing.lg),
      headerBottomSpacing: widget.mobile ? null : spacing.md,
      child: Column(
        crossAxisAlignment: widget.mobile
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.start,
        children: [
          Text(
            l10n.apiKeysDescription,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: widget.mobile ? spacing.md : spacing.lg),
          if (showInitialLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: widget.mobile ? spacing.lg : 0,
                ),
                child: const AppInlineSpinner(),
              ),
            )
          else if (asyncKeys.hasError && !asyncKeys.hasValue)
            Column(
              crossAxisAlignment: widget.mobile
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  apiErrorMessage(
                    asyncKeys.error!,
                    fallback: l10n.errorApiKeysLoadFailed,
                    l10n: l10n,
                  ),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.error,
                  ),
                ),
                SizedBox(height: spacing.sm),
                AppButton(
                  key: widget.mobile
                      ? const Key('mobile-account-apikeys-retry-button')
                      : const Key('configuration-api-keys-retry-button'),
                  label: l10n.commonRetry,
                  size: AppButtonSize.small,
                  onPressed: () => ref.invalidate(apiKeysProvider),
                ),
              ],
            )
          else if (keys.isEmpty)
            Text(
              l10n.apiKeysEmpty,
              style: resolveAppTextStyle(
                context,
                size: widget.mobile ? AppTextSize.s12 : AppTextSize.s14,
                tone: AppTextTone.muted,
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < keys.length; index++) ...[
                  if (index > 0)
                    Divider(height: 1, color: context.appColors.divider),
                  _buildApiKeyRow(context, keys[index]),
                ],
              ],
            ),
          SizedBox(height: spacing.lg),
          if (widget.mobile)
            AppButton(
              key: const Key('mobile-account-apikeys-create-button'),
              label: l10n.apiKeysGenerate,
              variant: AppButtonVariant.secondary,
              icon: const Icon(Icons.add_rounded),
              onPressed: _openGeneratePanel,
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  key: const Key('configuration-api-keys-create-button'),
                  label: l10n.apiKeysGenerate,
                  variant: AppButtonVariant.secondary,
                  icon: const Icon(Icons.add_rounded),
                  onPressed: _openGeneratePanel,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildApiKeyRow(BuildContext context, ApiKeyDto key) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final title = key.name.isEmpty ? l10n.apiKeyUnnamed : key.name;
    final createdAt = formatUpdatedAtLabel(key.createdAt);
    final lastUsedAt = formatUpdatedAtLabel(key.lastUsedAt);
    final lastUsed = lastUsedAt == null
        ? l10n.apiKeyNeverUsed
        : l10n.apiKeyLastUsed(lastUsedAt);
    final subtitle = <String>[
      key.keyHint,
      if (!widget.mobile && createdAt != null) l10n.apiKeyCreatedAt(createdAt),
      lastUsed,
    ].join(' · ');
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: widget.mobile ? spacing.sm : spacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s14,
                    weight: AppTextWeight.medium,
                    tone: AppTextTone.primary,
                  ),
                ),
                SizedBox(height: spacing.xs),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.muted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: spacing.sm),
          AppIconButton(
            key: widget.mobile
                ? Key('mobile-account-apikey-delete-${key.id}')
                : Key('configuration-api-key-delete-${key.id}'),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: l10n.commonDelete,
            onPressed: () => _deleteApiKey(key),
          ),
        ],
      ),
    );
  }

  Future<void> _openGeneratePanel() async {
    if (widget.mobile) {
      await showAppBottomDrawer<void>(
        context: context,
        drawerKey: const Key('mobile-api-key-generate-drawer'),
        maxHeightFactor: 0.6,
        builder: (_) => const ApiKeyGeneratePanel(keyPrefix: 'mobile'),
      );
      return;
    }
    await showAppDialog<void>(
      context: context,
      builder: (_) => const _ApiKeyGenerateDialog(),
    );
  }

  Future<void> _deleteApiKey(ApiKeyDto key) async {
    final l10n = AppLocalizations.of(context);
    final label = key.name.isEmpty ? key.keyHint : key.name;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.apiKeyDeleteTitle,
      message: l10n.apiKeyDeleteMessage(label),
      confirmLabel: l10n.commonDelete,
      danger: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(apiKeysProvider.notifier).delete(key.id);
    } catch (error) {
      if (mounted) {
        showToast(
          apiErrorMessage(
            error,
            fallback: l10n.errorApiKeyDeleteFailed,
            l10n: l10n,
          ),
          tone: AppToastTone.error,
        );
      }
    }
  }
}

class _AccountInfoRow extends StatelessWidget {
  const _AccountInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
        SizedBox(width: context.appSpacing.md),
        Expanded(
          child: Text(
            value,
            key: Key('mobile-account-summary-$label'),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.medium,
              tone: AppTextTone.primary,
            ),
          ),
        ),
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
          label: AppLocalizations.of(context).commonRetry,
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
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: spacing.md,
      runSpacing: spacing.sm,
      children: [
        _AccountProfilePill(
          label: l10n.accountCurrentUsername,
          value: account.username,
        ),
        _AccountProfilePill(
          label: l10n.accountCreatedAt,
          value: formatUpdatedAtLabel(account.createdAt) ?? l10n.commonUnknown,
        ),
        _AccountProfilePill(
          label: l10n.accountLastLogin,
          value:
              formatUpdatedAtLabel(account.lastLoginAt) ?? l10n.commonUnknown,
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

class _ApiKeyGenerateDialog extends StatelessWidget {
  const _ApiKeyGenerateDialog();

  @override
  Widget build(BuildContext context) {
    return AppDesktopDialog(
      width: context.appComponentTokens.playlistDialogWidth,
      child: const ApiKeyGeneratePanel(keyPrefix: 'configuration'),
    );
  }
}
