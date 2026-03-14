import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.platform});

  final AppPlatform platform;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _baseUrlFocusNode = FocusNode();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isSubmitting = false;
  bool _isPasswordObscured = true;
  bool _hasAttemptedSubmit = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _baseUrlController.text = context.read<SessionStore>().baseUrl;
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _baseUrlFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (_isSubmitting) {
      return;
    }

    if (!_hasAttemptedSubmit) {
      setState(() {
        _hasAttemptedSubmit = true;
      });
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final sessionStore = context.read<SessionStore>();
    final authApi = context.read<AuthApi>();

    try {
      await sessionStore.saveBaseUrl(_baseUrlController.text.trim());
      await authApi.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }
      context.go(overviewPathForPlatform(widget.platform));
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitError =
            error.error?.message.isNotEmpty == true
                ? error.error!.message
                : (error.message.isNotEmpty ? error.message : '登录失败，请稍后重试');
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitError = '登录失败，请检查网络或服务器地址';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String? _validateBaseUrl(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '请输入服务器 BaseURL';
    }

    final uri = Uri.tryParse(text);
    final isHttp =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final hasHost = uri != null && uri.host.isNotEmpty;
    if (!isHttp || !hasHost) {
      return '请输入有效的 http(s) 地址';
    }
    return null;
  }

  String? _validateRequired(String label, String? value) {
    if ((value ?? '').trim().isEmpty) {
      return '请输入$label';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final radius = context.appRadius;
    final textTheme = Theme.of(context).textTheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final isCompact = MediaQuery.of(context).size.width < 640;

    return Scaffold(
      backgroundColor: colors.surfacePage,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              colors.surfacePage,
              Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.18),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = isCompact ? spacing.lg : spacing.xxxl;
              final topPadding = spacing.xxl;
              final bottomPadding = spacing.xxl + viewInsets.bottom;
              final availableHeight =
                  constraints.maxHeight - topPadding - bottomPadding;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  bottomPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: math.max(0, availableHeight),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Container(
                        key: const Key('login-main-card'),
                        padding: EdgeInsets.all(spacing.xl),
                        decoration: BoxDecoration(
                          color: colors.surfaceCard.withValues(alpha: 0.94),
                          borderRadius: radius.lgBorder,
                          border: Border.all(color: colors.borderSubtle),
                          boxShadow: context.appShadows.card,
                        ),
                        child: Form(
                          key: _formKey,
                          autovalidateMode:
                              _hasAttemptedSubmit
                                  ? AutovalidateMode.onUserInteraction
                                  : AutovalidateMode.disabled,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.lock_outline_rounded,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                  SizedBox(width: spacing.sm),
                                  Text(
                                    'SakuraMedia',
                                    style: textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              SizedBox(height: spacing.lg),
                              Text('登录', style: textTheme.bodyMedium),
                              SizedBox(height: spacing.sm),
                              Text(
                                '请输入服务器地址与账号信息',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              SizedBox(height: spacing.xl),
                              AppTextField(
                                fieldKey: const Key('login-form-base-url'),
                                controller: _baseUrlController,
                                focusNode: _baseUrlFocusNode,
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.next,
                                enabled: !_isSubmitting,
                                validator: _validateBaseUrl,
                                onFieldSubmitted:
                                    (_) => _usernameFocusNode.requestFocus(),
                                hintText: '服务器地址，例如 http://127.0.0.1:38000',
                                prefix: Icon(
                                  Icons.dns_outlined,
                                  size: context.appComponentTokens.iconSizeMd,
                                  color: context.appColors.textMuted,
                                ),
                              ),
                              SizedBox(height: spacing.lg),
                              AppTextField(
                                fieldKey: const Key('login-form-username'),
                                controller: _usernameController,
                                focusNode: _usernameFocusNode,
                                textInputAction: TextInputAction.next,
                                enabled: !_isSubmitting,
                                validator:
                                    (value) => _validateRequired('用户名', value),
                                onFieldSubmitted:
                                    (_) => _passwordFocusNode.requestFocus(),
                                hintText: '用户名',
                                prefix: Icon(
                                  Icons.person_outline_rounded,
                                  size: context.appComponentTokens.iconSizeMd,
                                  color: context.appColors.textMuted,
                                ),
                              ),
                              SizedBox(height: spacing.lg),
                              AppTextField(
                                fieldKey: const Key('login-form-password'),
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                obscureText: _isPasswordObscured,
                                textInputAction: TextInputAction.done,
                                enabled: !_isSubmitting,
                                validator:
                                    (value) => _validateRequired('密码', value),
                                onFieldSubmitted: (_) => _submitLogin(),
                                hintText: '密码',
                                prefix: Icon(
                                  Icons.lock_outline_rounded,
                                  size: context.appComponentTokens.iconSizeMd,
                                  color: context.appColors.textMuted,
                                ),
                                suffix: AppIconButton(
                                  key: const Key('login-password-toggle'),
                                  tooltip:
                                      _isPasswordObscured ? '显示密码' : '隐藏密码',
                                  padding: EdgeInsets.all(
                                    context.appSpacing.xs,
                                  ),
                                  onPressed:
                                      _isSubmitting
                                          ? null
                                          : () {
                                            setState(() {
                                              _isPasswordObscured =
                                                  !_isPasswordObscured;
                                            });
                                          },
                                  icon: Icon(
                                    _isPasswordObscured
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: context.appComponentTokens.iconSizeSm,
                                  ),
                                ),
                              ),
                              if (_submitError != null) ...<Widget>[
                                SizedBox(height: spacing.md),
                                Container(
                                  key: const Key('login-error-message'),
                                  padding: EdgeInsets.all(spacing.md),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .errorContainer
                                        .withValues(alpha: 0.65),
                                    borderRadius: radius.mdBorder,
                                  ),
                                  child: Text(
                                    _submitError!,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                              SizedBox(height: spacing.xl),
                              SizedBox(
                                height: 48,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: radius.pillBorder,
                                    boxShadow:
                                        _isSubmitting
                                            ? const <BoxShadow>[]
                                            : <BoxShadow>[
                                              BoxShadow(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withValues(alpha: 0.22),
                                                blurRadius: 18,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                  ),
                                  child: ElevatedButton(
                                    key: const Key('login-submit-button'),
                                    onPressed:
                                        _isSubmitting ? null : _submitLogin,
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor:
                                          Theme.of(context).colorScheme.primary,
                                      foregroundColor:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                      disabledBackgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.55),
                                      disabledForegroundColor: Theme.of(context)
                                          .colorScheme
                                          .onPrimary
                                          .withValues(alpha: 0.92),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: radius.pillBorder,
                                      ),
                                    ),
                                    child:
                                        _isSubmitting
                                            ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: <Widget>[
                                                SizedBox(
                                                  width: spacing.lg,
                                                  height: spacing.lg,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .onPrimary,
                                                        ),
                                                  ),
                                                ),
                                                SizedBox(width: spacing.md),
                                                Text(
                                                  '登录中...',
                                                  style: textTheme.labelLarge
                                                      ?.copyWith(
                                                        color:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .onPrimary,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ],
                                            )
                                            : Text(
                                              '登录',
                                              style: textTheme.labelLarge
                                                  ?.copyWith(
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.onPrimary,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
