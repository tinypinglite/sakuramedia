import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/format/updated_at_label.dart';
import 'package:sakuramedia/features/account/data/account_api.dart';
import 'package:sakuramedia/features/account/data/account_dto.dart';
import 'package:sakuramedia/features/account/presentation/account_profile_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

class MobileChangeUsernamePage extends StatefulWidget {
  const MobileChangeUsernamePage({super.key});

  @override
  State<MobileChangeUsernamePage> createState() =>
      _MobileChangeUsernamePageState();
}

class _MobileChangeUsernamePageState extends State<MobileChangeUsernamePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final AccountProfileController _controller;
  late final TextEditingController _usernameController;
  late final FocusNode _usernameFocusNode;
  bool _hasAttemptedSubmit = false;

  AutovalidateMode get _autovalidateMode =>
      _hasAttemptedSubmit
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled;

  bool get _canSubmit =>
      !_controller.isLoading &&
      !_controller.isSaving &&
      _controller.account != null;

  @override
  void initState() {
    super.initState();
    _controller = AccountProfileController(
      accountApi: context.read<AccountApi>(),
    );
    _usernameController =
        TextEditingController()..addListener(_handleInputChanged);
    _usernameFocusNode = FocusNode();
    _loadAccount();
  }

  @override
  void dispose() {
    _controller.dispose();
    _usernameController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    await _controller.load();
    if (!mounted) {
      return;
    }
    final username = _controller.account?.username ?? '';
    _usernameController.text = username;
  }

  void _handleInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (_controller.isSaving) {
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

    final saved = await _controller.saveUsername(_usernameController.text);
    if (!mounted) {
      return;
    }

    if (saved) {
      _usernameController.text = _controller.account?.username ?? '';
      showToast('用户名已更新');
      return;
    }

    final message = _controller.errorMessage;
    if (message != null && message.isNotEmpty) {
      showToast(message);
    }
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入用户名';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final spacing = context.appSpacing;
        final colors = context.appColors;
        final viewInsets = MediaQuery.of(context).viewInsets;

        return ColoredBox(
          key: const Key('mobile-settings-username'),
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
                  child: _buildBody(context),
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
                    key: const Key('mobile-username-submit-button'),
                    label: _controller.isSaving ? '保存中' : '保存用户名',
                    variant: AppButtonVariant.primary,
                    isLoading: _controller.isSaving,
                    onPressed: _canSubmit ? _submit : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final spacing = context.appSpacing;

    if (_controller.isLoading && _controller.account == null) {
      return const _MobileUsernameLoadingSection();
    }

    if (_controller.errorMessage != null && _controller.account == null) {
      return _MobileUsernameErrorSection(
        message: _controller.errorMessage!,
        onRetry: _loadAccount,
      );
    }

    final account = _controller.account;
    return Form(
      key: _formKey,
      autovalidateMode: _autovalidateMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppNoticeCard(
            key: Key('mobile-username-notice-card'),
            leadingIcon: Icons.info_outline_rounded,
            description: '用户名会用于登录和账号识别，保存后当前登录态保持不变。',
          ),
          SizedBox(height: spacing.md),
          if (account != null) ...[
            _AccountSummaryCard(account: account),
            SizedBox(height: spacing.md),
          ],
          _FormCard(
            children: [
              AppTextField(
                fieldKey: const Key('mobile-username-field'),
                controller: _usernameController,
                focusNode: _usernameFocusNode,
                label: '用户名',
                hintText: '请输入新的用户名',
                enabled: !_controller.isSaving,
                validator: _validateUsername,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_controller.errorMessage != null && account != null) ...[
                SizedBox(height: spacing.sm),
                Text(
                  _controller.errorMessage!,
                  key: const Key('mobile-username-error-text'),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    tone: AppTextTone.error,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MobileUsernameLoadingSection extends StatelessWidget {
  const _MobileUsernameLoadingSection();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SkeletonBlock(height: 92, borderRadius: context.appRadius.mdBorder),
        SizedBox(height: spacing.md),
        _SkeletonBlock(height: 112, borderRadius: context.appRadius.lgBorder),
        SizedBox(height: spacing.md),
        _SkeletonBlock(height: 92, borderRadius: context.appRadius.lgBorder),
      ],
    );
  }
}

class _MobileUsernameErrorSection extends StatelessWidget {
  const _MobileUsernameErrorSection({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _FormCard(
      children: [
        AppEmptyState(
          message: message,
          retryKey: const Key('mobile-username-retry-button'),
          onRetry: onRetry,
        ),
      ],
    );
  }
}

class _AccountSummaryCard extends StatelessWidget {
  const _AccountSummaryCard({required this.account});

  final AccountDto account;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return _FormCard(
      key: const Key('mobile-username-summary-card'),
      children: [
        Text(
          '当前账号',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.md),
        _AccountInfoRow(label: '用户名', value: account.username),
        SizedBox(height: spacing.sm),
        _AccountInfoRow(
          label: '创建时间',
          value: formatUpdatedAtLabel(account.createdAt) ?? '未知',
        ),
        SizedBox(height: spacing.sm),
        _AccountInfoRow(
          label: '上次登录',
          value: formatUpdatedAtLabel(account.lastLoginAt) ?? '未知',
        ),
      ],
    );
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
            key: Key('mobile-username-summary-$label'),
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

class _FormCard extends StatelessWidget {
  const _FormCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: key == null ? const Key('mobile-username-form-card') : null,
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

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height, required this.borderRadius});

  final double height;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: borderRadius,
      ),
    );
  }
}

