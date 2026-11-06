import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/account/presentation/providers/account_api_provider.dart';
import 'package:sakuramedia/features/auth/presentation/providers/auth_api_provider.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/account/data/account_dto.dart';
import 'package:sakuramedia/features/account/presentation/account_placeholders.dart';
import 'package:sakuramedia/features/account/presentation/providers/account_profile_provider.dart';
import 'package:sakuramedia/features/account/presentation/providers/account_profile_state.dart';
import 'package:sakuramedia/features/account/presentation/providers/api_keys_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_password_field.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';
import 'package:sakuramedia/widgets/domain/account/api_key_generate_panel.dart';

class AccountSecuritySection extends ConsumerStatefulWidget {
  const AccountSecuritySection({super.key, required this.active});

  final bool active;

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
    _usernameController = TextEditingController()
      ..addListener(_handleUsernameChanged);
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
      showToast(
        AppLocalizations.of(context).accountUsernameUpdated,
        tone: AppToastTone.success,
      );
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
        if (!mounted) {
          return;
        }
        showToast(
          AppLocalizations.of(context).accountPasswordChangedReloginFailed,
          tone: AppToastTone.error,
        );
        return;
      }

      if (!mounted) {
        return;
      }
      showToast(
        AppLocalizations.of(context).accountPasswordChangedRelogin,
        tone: AppToastTone.success,
      );
      await context.logOut();
    } catch (error) {
      if (!mounted) {
        return;
      }
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

  Future<void> _refresh() async {
    if (_isSubmitting || ref.read(accountProfileProvider).isSaving) {
      return;
    }
    await ref.read(accountProfileProvider.notifier).load();
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context).accountCurrentPasswordRequired;
    }
    return null;
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context).errorUsernameRequired;
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

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final profileState = ref.watch(accountProfileProvider);
    _syncInitialUsername(profileState);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAccountProfileCard(context, profileState),
        SizedBox(height: spacing.xl),
        _buildPasswordCard(context),
        SizedBox(height: spacing.xl),
        _buildApiKeysCard(context),
      ],
    );
    return widget.active
        ? AppPageRefreshScope(onRefresh: _refresh, child: content)
        : content;
  }

  Widget _buildAccountProfileCard(
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
      title: l10n.accountProfileTitle,
      padding: EdgeInsets.all(spacing.lg),
      headerBottomSpacing: spacing.md,
      // loading 用占位账号渲染真实资料卡与表单壳，由 [AppSkeletonizer] 灰化。
      child: AppSkeletonizer(
        enabled: showSkeleton,
        child: Form(
          key: _profileFormKey,
          autovalidateMode: _hasAttemptedUsernameSubmit
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (profileState.errorMessage != null && account == null)
                _AccountProfileErrorBlock(
                  message: profileState.errorMessage!,
                  onRetry: () =>
                      ref.read(accountProfileProvider.notifier).load(),
                )
              else ...[
                Text(
                  l10n.accountUsernameHelpDesktop,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.muted,
                  ),
                ),
                if (displayAccount != null) ...[
                  SizedBox(height: spacing.lg),
                  _AccountProfileSummary(account: displayAccount),
                ],
                SizedBox(height: spacing.lg),
                AppTextField(
                  fieldKey: const Key('configuration-username-field'),
                  controller: _usernameController,
                  label: l10n.accountUsername,
                  hintText: l10n.accountUsernameHint,
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
                    label: l10n.accountSaveUsername,
                    variant: AppButtonVariant.primary,
                    isLoading: profileState.isSaving,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordCard(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);

    return AppContentCard(
      title: l10n.accountChangePasswordTitle,
      padding: EdgeInsets.all(spacing.lg),
      headerBottomSpacing: spacing.md,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.accountChangePasswordNotice,
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
              label: l10n.accountCurrentPassword,
              validator: _validateCurrentPassword,
            ),
            SizedBox(height: spacing.lg),
            AppPasswordField(
              fieldKey: const Key('configuration-password-new-field'),
              controller: _newPasswordController,
              label: l10n.accountNewPassword,
              validator: _validateNewPassword,
            ),
            SizedBox(height: spacing.lg),
            AppPasswordField(
              fieldKey: const Key('configuration-password-confirm-field'),
              controller: _confirmPasswordController,
              label: l10n.accountConfirmNewPassword,
              validator: _validateConfirmPassword,
            ),
            SizedBox(height: spacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton(
                  key: const Key('configuration-password-reset-button'),
                  onPressed: _isSubmitting ? null : _reset,
                  label: l10n.accountReset,
                ),
                SizedBox(width: spacing.md),
                AppButton(
                  key: const Key('configuration-password-submit-button'),
                  onPressed: _submit,
                  label: l10n.accountChangePasswordTitle,
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

  Widget _buildApiKeysCard(BuildContext context) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final asyncKeys = ref.watch(apiKeysProvider);
    final keys = asyncKeys.value ?? const <ApiKeyDto>[];
    final showInitialLoading = asyncKeys.isLoading && !asyncKeys.hasValue;

    return AppContentCard(
      title: l10n.apiKeysTitle,
      padding: EdgeInsets.all(spacing.lg),
      headerBottomSpacing: spacing.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.apiKeysDescription,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: spacing.lg),
          if (showInitialLoading)
            const Center(child: AppInlineSpinner())
          else if (asyncKeys.hasError && !asyncKeys.hasValue)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  key: const Key('configuration-api-keys-retry-button'),
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
                size: AppTextSize.s14,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                key: const Key('configuration-api-keys-create-button'),
                label: l10n.apiKeysGenerate,
                variant: AppButtonVariant.secondary,
                icon: const Icon(Icons.add_rounded),
                onPressed: () => _generateApiKey(context),
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
      if (createdAt != null) l10n.apiKeyCreatedAt(createdAt),
      lastUsed,
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.md),
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
            key: Key('configuration-api-key-delete-${key.id}'),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: l10n.commonDelete,
            onPressed: () => _deleteApiKey(context, key),
          ),
        ],
      ),
    );
  }

  Future<void> _generateApiKey(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => const _ApiKeyGenerateDialog(),
    );
  }

  Future<void> _deleteApiKey(BuildContext context, ApiKeyDto key) async {
    final l10n = AppLocalizations.of(context);
    final label = key.name.isEmpty ? key.keyHint : key.name;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.apiKeyDeleteTitle,
      message: l10n.apiKeyDeleteMessage(label),
      confirmLabel: l10n.commonDelete,
      danger: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(apiKeysProvider.notifier).delete(key.id);
    } catch (error) {
      if (context.mounted) {
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
