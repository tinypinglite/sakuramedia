import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/shell/window/app_windows_caption.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/language/app_language.dart';
import 'package:sakuramedia/app/language/providers/language_providers.dart';
import 'package:sakuramedia/features/account/presentation/providers/account_api_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/providers/credential_store_provider.dart';
import 'package:sakuramedia/features/auth/presentation/providers/auth_api_provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/providers/external_url_provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';
import 'package:sakuramedia/widgets/base/layout/badges/app_media_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

const double _desktopBreakpoint = 980;
const double _wideViewportMinHeight = 700;
const double _scrollFallbackMinHeight = 560;
const double _largeTextThreshold = 1.25;

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, required this.platform});

  final AppPlatform platform;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
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
  bool _languageTouched = false;
  String? _submitError;
  bool _showFirstRunNotice = false;
  bool _showDeployHelp = false;
  String _protocol = 'http';

  @override
  void initState() {
    super.initState();
    final savedBaseUrl = ref.read(sessionStoreProvider).baseUrl;
    _initBaseUrl(savedBaseUrl);
    _showFirstRunNotice = savedBaseUrl.trim().isEmpty;
    _loadSavedCredentials();
  }

  void _initBaseUrl(String savedBaseUrl) {
    final match = RegExp(r'^(https?)://').firstMatch(savedBaseUrl.trim());
    if (match != null) {
      _protocol = match.group(1)!;
      _baseUrlController.text = savedBaseUrl.trim().substring(match.end);
    } else {
      _baseUrlController.text = savedBaseUrl.trim();
    }
  }

  String _composeBaseUrl() => '$_protocol://${_baseUrlController.text.trim()}';

  Future<void> _loadSavedCredentials() async {
    final credentialStore = ref.read(credentialStoreProvider);
    final username = await credentialStore.readUsername();
    final password = await credentialStore.readPassword();
    if (!mounted) return;
    if (username != null && username.isNotEmpty) {
      _usernameController.text = username;
    }
    if (password != null && password.isNotEmpty) {
      _passwordController.text = password;
    }
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

    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _submitError = null;
      _showDeployHelp = false;
    });

    final sessionStore = ref.read(sessionStoreProvider);
    final authApi = ref.read(authApiProvider);
    final accountApi = ref.read(accountApiProvider);
    final selectedLanguage = ref.read(appLanguageControllerProvider);

    try {
      await sessionStore.saveBaseUrl(_composeBaseUrl());
      final tokens = await authApi.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (_languageTouched) {
        // 登录页的显式选择优先；保存失败不阻塞进入应用，设置页可重试。
        try {
          await accountApi.updateLanguage(selectedLanguage.apiTag);
        } catch (_) {
          // 语言已保存在本机，下一次切换/登录还会再次同步。
        }
      } else {
        await ref
            .read(appLanguageControllerProvider.notifier)
            .applyServerLanguage(tokens.user.language);
      }

      if (!mounted) {
        return;
      }
      context.go(overviewPathForPlatform(widget.platform));
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitError = apiErrorMessage(
          error,
          fallback: l10n.loginErrorFallback,
          l10n: l10n,
        );
        _showDeployHelp = error.isTransportFailure;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitError = l10n.loginErrorNetwork;
        _showDeployHelp = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  static const _deployGuideUrl =
      'https://tinypinglite.github.io/sakuramedia/guide/quick-start';

  Future<void> _openDeployGuide() async {
    final l10n = AppLocalizations.of(context);
    final opened = await ref.read(externalUrlOpenerProvider)(
      Uri.parse(_deployGuideUrl),
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.loginOpenBrowserFailed)));
    }
  }

  void _dismissFirstRunNotice() {
    setState(() => _showFirstRunNotice = false);
  }

  Future<void> _showFirstRunDetails() async {
    if (_isSubmitting) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    await showAppAdaptiveModal<void>(
      context: context,
      modalKey: const Key('login-first-run-modal'),
      desktopWidth: 440,
      mobileMaxHeightFactor: 0.8,
      variant: widget.platform == AppPlatform.mobile
          ? AppAdaptiveModalVariant.drawer
          : AppAdaptiveModalVariant.dialog,
      builder: (modalContext) {
        final spacing = modalContext.appSpacing;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppNoticeCard(
              leadingIcon: Icons.dns_outlined,
              title: l10n.loginFirstRunTitle,
              description: l10n.loginFirstRunDescription,
            ),
            SizedBox(height: spacing.lg),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                key: const Key('login-open-deploy-guide'),
                label: l10n.loginViewDeployGuide,
                variant: AppButtonVariant.primary,
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: _isSubmitting ? null : _openDeployGuide,
              ),
            ),
            SizedBox(height: spacing.sm),
            AppTextButton(
              key: const Key('login-dismiss-first-run-modal'),
              label: l10n.loginHaveServer,
              onPressed: () {
                Navigator.of(modalContext).pop();
                if (mounted) {
                  _dismissFirstRunNotice();
                }
              },
            ),
          ],
        );
      },
    );
  }

  String? _validateBaseUrl(AppLocalizations l10n, String? value) {
    final host = value?.trim() ?? '';
    if (host.isEmpty) {
      return l10n.loginServerRequired;
    }
    if (host.contains(RegExp(r'\s'))) {
      return l10n.loginServerInvalid;
    }

    final uri = Uri.tryParse('$_protocol://$host');
    if (uri == null || uri.host.isEmpty) {
      return l10n.loginServerInvalid;
    }
    return null;
  }

  /// 用户在地址框中粘贴/输入完整 URL（含协议）时，自动剥离协议前缀并切换下拉。
  void _handleBaseUrlChanged(String value) {
    final match = RegExp(r'^(https?)://').firstMatch(value);
    if (match == null) {
      return;
    }
    final scheme = match.group(1)!;
    final rest = value.substring(match.end);
    setState(() {
      _protocol = scheme;
    });
    _baseUrlController.value = TextEditingValue(
      text: rest,
      selection: TextSelection.collapsed(offset: rest.length),
    );
  }

  void _handleProtocolChanged(String protocol) {
    if (protocol == _protocol) {
      return;
    }
    setState(() {
      _protocol = protocol;
    });
  }

  void _handleLanguageSelected(AppLanguage language) {
    setState(() {
      _languageTouched = true;
    });
    unawaited(
      ref.read(appLanguageControllerProvider.notifier).setLanguage(language),
    );
  }

  String? _validateRequired(
    AppLocalizations l10n,
    String label,
    String? value,
  ) {
    if ((value ?? '').trim().isEmpty) {
      return l10n.loginFieldRequired(label);
    }
    return null;
  }

  double _fieldHeight(BuildContext context) {
    final largeText =
        MediaQuery.textScalerOf(context).scale(14) / 14 > _largeTextThreshold;
    return context.appComponentTokens.buttonHeightLg + (largeText ? 8 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLanguage = ref.watch(appLanguageControllerProvider);
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Scaffold(
      appBar: usesAppWindowsCaption
          ? PreferredSize(
              preferredSize: Size.fromHeight(
                context.appComponentTokens.desktopTitleBarHeight,
              ),
              child: const AppWindowsCaption(standalone: true),
            )
          : null,
      backgroundColor: colors.surfacePage,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const _LoginAtmosphere(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(14) / 14 >
                    _largeTextThreshold;
                final wideLayout =
                    constraints.maxWidth >= _desktopBreakpoint &&
                    constraints.maxHeight >= _wideViewportMinHeight &&
                    !largeText;
                final scrollFallback =
                    viewInsets.bottom > 0 ||
                    largeText ||
                    constraints.maxHeight < _scrollFallbackMinHeight ||
                    _submitError != null;
                final horizontalPadding = wideLayout
                    ? spacing.xxxl + spacing.xl
                    : spacing.lg;
                final topPadding = wideLayout
                    ? spacing.xxl + spacing.md
                    : spacing.lg;
                final bottomPadding = wideLayout ? spacing.xxl : spacing.lg;
                final availableHeight = math.max(
                  0.0,
                  constraints.maxHeight - topPadding - bottomPadding,
                );
                final heroWidth = math.min(540.0, constraints.maxWidth * 0.46);

                final content = ConstrainedBox(
                  constraints: BoxConstraints(minHeight: availableHeight),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _hasAttemptedSubmit
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: wideLayout
                        ? _buildWideLayout(
                            context,
                            l10n,
                            currentLanguage: currentLanguage,
                            heroWidth: heroWidth,
                          )
                        : _buildCompactLayout(
                            context,
                            l10n,
                            currentLanguage: currentLanguage,
                          ),
                  ),
                );
                final padding = EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  bottomPadding,
                );

                if (!scrollFallback) {
                  return Padding(padding: padding, child: content);
                }

                return SingleChildScrollView(
                  key: const Key('login-page-scroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const ClampingScrollPhysics(),
                  padding: padding,
                  child: content,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    AppLocalizations l10n, {
    required AppLanguage currentLanguage,
  }) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildTopBar(context, currentLanguage: currentLanguage),
        SizedBox(height: spacing.lg),
        if (_showFirstRunNotice) ...<Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _buildCompactFirstRunEntry(context, l10n),
            ),
          ),
          SizedBox(height: spacing.md),
        ],
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _buildCompactFormPanel(context, l10n),
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    AppLocalizations l10n, {
    required AppLanguage currentLanguage,
    required double heroWidth,
  }) {
    final spacing = context.appSpacing;
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildTopBar(context, currentLanguage: currentLanguage),
            SizedBox(height: spacing.xxl + spacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: heroWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildHero(context, l10n, compact: false),
                    if (_showFirstRunNotice) ...[
                      SizedBox(height: spacing.xl),
                      _buildFirstRunNotice(context, l10n),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.only(top: spacing.xxl),
          child: _buildDesktopFormDock(context, l10n),
        ),
      ],
    );
  }

  Widget _buildTopBar(
    BuildContext context, {
    required AppLanguage currentLanguage,
  }) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: context.appSpacing.lg,
      runSpacing: context.appSpacing.sm,
      children: <Widget>[
        const _AuthBrandLockup(),
        _LoginLanguageSwitcher(
          current: currentLanguage,
          enabled: !_isSubmitting,
          onSelected: _handleLanguageSelected,
        ),
      ],
    );
  }

  Widget _buildHero(
    BuildContext context,
    AppLocalizations l10n, {
    required bool compact,
  }) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.loginHeroEyebrow,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s10,
            weight: AppTextWeight.medium,
            tone: AppTextTone.muted,
          ).copyWith(letterSpacing: compact ? 1.6 : 2.2),
        ),
        SizedBox(height: compact ? spacing.sm : spacing.lg),
        Text(
          l10n.loginHeroTitle,
          style:
              resolveAppTextStyle(
                context,
                size: compact ? AppTextSize.s32 : AppTextSize.s48,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ).copyWith(
                height: compact ? 1.18 : 1.16,
                letterSpacing: compact ? -0.4 : -1,
              ),
        ),
        SizedBox(height: compact ? spacing.sm : spacing.lg),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Text(
            l10n.loginHeroDescription,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              tone: AppTextTone.secondary,
            ).copyWith(height: 1.7),
          ),
        ),
      ],
    );
  }

  Widget _buildFirstRunNotice(BuildContext context, AppLocalizations l10n) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppNoticeCard(
          key: const Key('login-first-run-notice'),
          leadingIcon: Icons.dns_outlined,
          title: l10n.loginFirstRunTitle,
          description: l10n.loginFirstRunDescription,
        ),
        SizedBox(height: spacing.sm),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.xs,
          children: <Widget>[
            AppTextButton(
              key: const Key('login-open-deploy-guide'),
              label: l10n.loginViewDeployGuide,
              icon: Icon(
                Icons.open_in_new_rounded,
                size: context.appComponentTokens.iconSizeSm,
              ),
              size: AppTextButtonSize.small,
              onPressed: _isSubmitting ? null : _openDeployGuide,
            ),
            AppTextButton(
              key: const Key('login-dismiss-first-run'),
              label: l10n.loginHaveServer,
              size: AppTextButtonSize.small,
              onPressed: _isSubmitting ? null : _dismissFirstRunNotice,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactFirstRunEntry(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final spacing = context.appSpacing;
    return Row(
      key: const Key('login-first-run-notice'),
      children: <Widget>[
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppTextButton(
              key: const Key('login-first-run-details'),
              label: l10n.loginFirstRunTitle,
              icon: Icon(
                Icons.dns_outlined,
                size: context.appComponentTokens.iconSizeSm,
              ),
              trailingIcon: Icon(
                Icons.chevron_right_rounded,
                size: context.appComponentTokens.iconSizeSm,
              ),
              size: AppTextButtonSize.small,
              emphasis: AppTextButtonEmphasis.accent,
              onPressed: _isSubmitting ? null : _showFirstRunDetails,
            ),
          ),
        ),
        SizedBox(width: spacing.xs),
        AppIconButton(
          key: const Key('login-dismiss-first-run'),
          tooltip: l10n.commonClose,
          icon: Icon(
            Icons.close_rounded,
            size: context.appComponentTokens.iconSizeSm,
          ),
          onPressed: _isSubmitting ? null : _dismissFirstRunNotice,
        ),
      ],
    );
  }

  Widget _buildDesktopFormDock(BuildContext context, AppLocalizations l10n) {
    final spacing = context.appSpacing;
    final radius = context.appRadius;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final buttonWidth = spacing.xxxl * 4 + spacing.lg;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surfaceElevated.withValues(
          alpha: dark ? 0.08 : 0.44,
        ),
        borderRadius: radius.xlBorder,
        boxShadow: context.appShadows.panel,
      ),
      child: AppSurface(
        key: const Key('login-main-card'),
        borderRadius: radius.xlBorder,
        padding: EdgeInsets.all(spacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          l10n.loginDockTitle,
                          overflow: TextOverflow.ellipsis,
                          style: resolveAppTextStyle(
                            context,
                            size: AppTextSize.s20,
                            weight: AppTextWeight.semibold,
                            tone: AppTextTone.primary,
                          ),
                        ),
                      ),
                      SizedBox(width: spacing.sm),
                      Flexible(
                        child: Text(
                          l10n.loginDockSubtitle,
                          overflow: TextOverflow.ellipsis,
                          style: resolveAppTextStyle(
                            context,
                            size: AppTextSize.s10,
                            tone: AppTextTone.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: spacing.md),
                _buildTrustLine(context, l10n),
              ],
            ),
            if (_submitError != null) ...<Widget>[
              SizedBox(height: spacing.md),
              _buildErrorBlock(context, l10n),
            ],
            SizedBox(height: spacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 4,
                  child: _buildServerField(context, l10n, compact: false),
                ),
                SizedBox(width: spacing.md),
                Expanded(flex: 2, child: _buildUsernameField(context, l10n)),
                SizedBox(width: spacing.md),
                Expanded(flex: 2, child: _buildPasswordField(context, l10n)),
                SizedBox(width: spacing.lg),
                Padding(
                  padding: EdgeInsets.only(top: spacing.lg + spacing.sm),
                  child: SizedBox(
                    width: buttonWidth,
                    child: _buildSubmitButton(context, l10n),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactFormPanel(BuildContext context, AppLocalizations l10n) {
    final spacing = context.appSpacing;
    final radius = context.appRadius;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardPadding = spacing.lg;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appColors.surfaceElevated.withValues(
          alpha: dark ? 0.08 : 0.44,
        ),
        borderRadius: radius.xlBorder,
        boxShadow: context.appShadows.panel,
      ),
      child: AppSurface(
        key: const Key('login-main-card'),
        borderRadius: radius.xlBorder,
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.loginWelcomeTitle,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s24,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ).copyWith(height: 1.12),
            ),
            SizedBox(height: spacing.lg),
            _buildServerField(context, l10n, compact: true),
            SizedBox(height: spacing.md),
            _buildUsernameField(context, l10n),
            SizedBox(height: spacing.md),
            _buildPasswordField(context, l10n),
            if (_submitError != null) ...<Widget>[
              SizedBox(height: spacing.md),
              _buildErrorBlock(context, l10n),
            ],
            SizedBox(height: spacing.lg),
            _buildSubmitButton(context, l10n),
            SizedBox(height: spacing.md),
            _buildTrustLine(context, l10n, centered: true),
          ],
        ),
      ),
    );
  }

  Widget _buildServerField(
    BuildContext context,
    AppLocalizations l10n, {
    required bool compact,
  }) {
    return AppTextField(
      fieldKey: const Key('login-form-base-url'),
      controller: _baseUrlController,
      focusNode: _baseUrlFocusNode,
      label: l10n.loginServerAddress,
      helperText: compact
          ? l10n.loginServerHelper
          : l10n.loginServerHelperShort,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.next,
      enabled: !_isSubmitting,
      validator: (value) => _validateBaseUrl(l10n, value),
      onChanged: _handleBaseUrlChanged,
      onFieldSubmitted: (_) => _usernameFocusNode.requestFocus(),
      hintText: '127.0.0.1:38000',
      prefix: _ProtocolPrefix(
        protocol: _protocol,
        enabled: !_isSubmitting,
        onChanged: _handleProtocolChanged,
      ),
      suffix: AppIconButton(
        key: const Key('login-base-url-help'),
        tooltip: l10n.loginServerHelpTooltip,
        padding: EdgeInsets.all(context.appSpacing.xs),
        onPressed: _isSubmitting ? null : _openDeployGuide,
        icon: Icon(
          Icons.help_outline_rounded,
          size: context.appComponentTokens.iconSizeSm,
        ),
      ),
      fillColor: _fieldFillColor(context),
      borderRadius: context.appRadius.mdBorder,
      height: _fieldHeight(context),
    );
  }

  Widget _buildUsernameField(BuildContext context, AppLocalizations l10n) {
    return AppTextField(
      fieldKey: const Key('login-form-username'),
      controller: _usernameController,
      focusNode: _usernameFocusNode,
      label: l10n.loginUsername,
      textInputAction: TextInputAction.next,
      enabled: !_isSubmitting,
      validator: (value) => _validateRequired(l10n, l10n.loginUsername, value),
      onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
      hintText: l10n.loginUsername,
      prefix: Icon(
        Icons.person_outline_rounded,
        size: context.appComponentTokens.iconSizeSm,
        color: context.appTextPalette.muted,
      ),
      fillColor: _fieldFillColor(context),
      borderRadius: context.appRadius.mdBorder,
      height: _fieldHeight(context),
    );
  }

  Widget _buildPasswordField(BuildContext context, AppLocalizations l10n) {
    return AppTextField(
      fieldKey: const Key('login-form-password'),
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      label: l10n.loginPassword,
      obscureText: _isPasswordObscured,
      textInputAction: TextInputAction.done,
      enabled: !_isSubmitting,
      validator: (value) => _validateRequired(l10n, l10n.loginPassword, value),
      onFieldSubmitted: (_) => _submitLogin(),
      hintText: l10n.loginPassword,
      prefix: Icon(
        Icons.lock_outline_rounded,
        size: context.appComponentTokens.iconSizeSm,
        color: context.appTextPalette.muted,
      ),
      suffix: AppIconButton(
        key: const Key('login-password-toggle'),
        tooltip: _isPasswordObscured
            ? l10n.loginShowPassword
            : l10n.loginHidePassword,
        padding: EdgeInsets.all(context.appSpacing.xs),
        onPressed: _isSubmitting
            ? null
            : () {
                setState(() {
                  _isPasswordObscured = !_isPasswordObscured;
                });
              },
        icon: Icon(
          _isPasswordObscured
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: context.appComponentTokens.iconSizeSm,
        ),
      ),
      fillColor: _fieldFillColor(context),
      borderRadius: context.appRadius.mdBorder,
      height: _fieldHeight(context),
    );
  }

  Widget _buildErrorBlock(BuildContext context, AppLocalizations l10n) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppInlineErrorBanner(
          key: const Key('login-error-message'),
          message: _submitError!,
          tone: AppInlineErrorTone.error,
        ),
        if (_showDeployHelp &&
            (defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.iOS)) ...[
          SizedBox(height: spacing.sm),
          _buildLocalNetworkPermissionHint(context, l10n),
        ],
        if (_showDeployHelp) ...<Widget>[
          SizedBox(height: spacing.sm),
          AppTextButton(
            key: const Key('login-error-deploy-guide'),
            label: l10n.loginDeployGuideInError,
            icon: Icon(
              Icons.open_in_new_rounded,
              size: context.appComponentTokens.iconSizeSm,
            ),
            size: AppTextButtonSize.small,
            onPressed: _isSubmitting ? null : _openDeployGuide,
          ),
        ],
      ],
    );
  }

  Widget _buildLocalNetworkPermissionHint(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final spacing = context.appSpacing;
    final hint = defaultTargetPlatform == TargetPlatform.iOS
        ? l10n.loginLocalNetworkPermissionHintIos
        : l10n.loginLocalNetworkPermissionHintMacos;
    return Row(
      key: const Key('login-local-network-permission-hint'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          Icons.wifi_tethering_rounded,
          size: context.appComponentTokens.iconSizeXs,
          color: context.appTextPalette.muted,
        ),
        SizedBox(width: spacing.xs),
        Expanded(
          child: Text(
            hint,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(BuildContext context, AppLocalizations l10n) {
    final radius = context.appRadius;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius.pillBorder,
        boxShadow: _isSubmitting
            ? const <BoxShadow>[]
            : <BoxShadow>[
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withValues(
                    alpha: context.appOverlayTokens.surfaceShadowAlpha,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: AppButton(
          key: const Key('login-submit-button'),
          label: _isSubmitting ? l10n.loginSubmitting : l10n.loginEnterLibrary,
          variant: AppButtonVariant.primary,
          size: AppButtonSize.large,
          borderRadius: radius.pillBorder,
          isLoading: _isSubmitting,
          trailingIcon: _isSubmitting
              ? null
              : const Icon(Icons.arrow_forward_rounded),
          disabledOpacity: 1,
          disabledBackgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.55),
          disabledForegroundColor: Theme.of(
            context,
          ).colorScheme.onPrimary.withValues(alpha: 0.92),
          onPressed: _isSubmitting ? null : _submitLogin,
        ),
      ),
    );
  }

  Widget _buildTrustLine(
    BuildContext context,
    AppLocalizations l10n, {
    bool centered = false,
  }) {
    final spacing = context.appSpacing;
    return Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.end,
      mainAxisSize: centered ? MainAxisSize.max : MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.shield_outlined,
          size: context.appComponentTokens.iconSize3xs,
          color: context.appTextPalette.muted,
        ),
        SizedBox(width: spacing.xs),
        Flexible(
          child: Text(
            l10n.loginTrustLine,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              tone: AppTextTone.muted,
            ),
          ),
        ),
      ],
    );
  }

  Color _fieldFillColor(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    return context.appColors.surfaceElevated.withValues(
      alpha: highContrast ? 0.96 : (dark ? 0.28 : 0.74),
    );
  }
}

class _AuthBrandLockup extends StatelessWidget {
  const _AuthBrandLockup();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final markSize = spacing.xxxl;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: markSize,
          height: markSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.surfaceElevated.withValues(alpha: dark ? 0.18 : 0.74),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Center(
                  child: Icon(
                    Icons.local_florist_rounded,
                    size: context.appComponentTokens.iconSizeMd,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: Image.asset(
                    'wiki/public/brand/sakuramedia-logo.png',
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: spacing.sm + spacing.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'SakuraMedia',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ).copyWith(letterSpacing: 0.1),
            ),
            Text(
              l10n.loginBrandTagline,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s10,
                weight: AppTextWeight.medium,
                tone: AppTextTone.muted,
              ).copyWith(letterSpacing: 1.35),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoginAtmosphere extends StatelessWidget {
  const _LoginAtmosphere();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colors = context.appColors;
        final scheme = Theme.of(context).colorScheme;
        final dark = Theme.of(context).brightness == Brightness.dark;
        final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
        if (highContrast) {
          return ColoredBox(color: colors.surfacePage);
        }

        final compact = constraints.maxWidth < _desktopBreakpoint;
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final primaryGlow = scheme.primary.withValues(alpha: dark ? 0.22 : 0.3);
        final warmGlow = scheme.tertiary.withValues(alpha: dark ? 0.14 : 0.2);

        return ExcludeSemantics(
          child: IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        colors.surfacePage,
                        Color.lerp(
                          colors.surfacePage,
                          scheme.primaryContainer,
                          dark ? 0.4 : 0.5,
                        )!,
                        Color.lerp(
                          colors.surfacePage,
                          scheme.tertiaryContainer,
                          dark ? 0.14 : 0.28,
                        )!,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: -width * 0.17,
                  top: -height * 0.26,
                  child: _LoginGlow(size: width * 0.68, color: primaryGlow),
                ),
                Positioned(
                  right: -width * 0.16,
                  bottom: -height * 0.3,
                  child: _LoginGlow(size: width * 0.72, color: warmGlow),
                ),
                Positioned(
                  right: width * 0.03,
                  top: -height * 0.14,
                  child: Opacity(
                    opacity: dark ? 0.09 : 0.11,
                    child: _SakuraMark(size: width * 0.54),
                  ),
                ),
                Positioned(
                  right: compact ? -width * 0.38 : width * 0.035,
                  top: compact ? height * 0.1 : height * 0.13,
                  child: _LoginCoverFan(compact: compact),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: <Color>[
                        colors.surfacePage.withValues(alpha: 0.96),
                        colors.surfacePage.withValues(alpha: 0.84),
                        colors.surfacePage.withValues(alpha: 0.2),
                        colors.surfacePage.withValues(alpha: 0),
                      ],
                      stops: const <double>[0, 0.4, 0.78, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: width * 0.05,
                  bottom: -height * 0.24,
                  child: _LoginGlow(
                    size: width * 0.85,
                    color: dark
                        ? scheme.primary.withValues(alpha: 0.1)
                        : colors.surfaceElevated.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LoginGlow extends StatelessWidget {
  const _LoginGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _LoginCoverFan extends StatelessWidget {
  const _LoginCoverFan({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final cardWidth = compact
        ? spacing.xxxl * 3 + spacing.xxl
        : spacing.xxxl * 5 + spacing.sm;
    final cardHeight = cardWidth * 1.44;
    return SizedBox(
      width: cardWidth * 3.3,
      height: cardHeight * 1.45,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: cardWidth * 0.08,
            top: cardHeight * 0.21,
            child: Transform.rotate(
              angle: -0.12,
              child: _LoginCoverArt(
                index: 0,
                width: cardWidth,
                height: cardHeight,
              ),
            ),
          ),
          Positioned(
            left: cardWidth * 0.82,
            top: cardHeight * 0.05,
            child: Transform.rotate(
              angle: -0.01,
              child: _LoginCoverArt(
                index: 1,
                width: cardWidth * 1.08,
                height: cardHeight * 1.08,
              ),
            ),
          ),
          Positioned(
            left: cardWidth * 1.72,
            top: cardHeight * 0.25,
            child: Transform.rotate(
              angle: 0.11,
              child: _LoginCoverArt(
                index: 2,
                width: cardWidth * 0.9,
                height: cardHeight * 0.92,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCoverArt extends StatelessWidget {
  const _LoginCoverArt({
    required this.index,
    required this.width,
    required this.height,
  });

  final int index;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final radius = context.appRadius;
    final palette = _loginCoverPalette(context, index);
    final highlight = context.appTextPalette.onMedia;

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius.mdBorder,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
        border: Border.all(color: highlight.withValues(alpha: 0.2)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.last.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: width * 0.18,
            top: height * 0.14,
            child: Container(
              width: width * 0.36,
              height: width * 0.36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    highlight.withValues(alpha: 0.42),
                    highlight.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: spacing.sm,
            top: spacing.sm,
            child: const AppMediaBadge(label: '4K'),
          ),
        ],
      ),
    );
  }
}

List<Color> _loginCoverPalette(BuildContext context, int index) {
  final scheme = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final source = switch (index % 3) {
    0 => scheme.primaryContainer,
    1 => scheme.secondaryContainer,
    _ => scheme.tertiaryContainer,
  };
  final hsl = HSLColor.fromColor(source);
  final hue = (hsl.hue + (index - 1) * 27) % 360;
  final saturation = hsl.saturation.clamp(dark ? 0.3 : 0.42, 0.72).toDouble();
  final topLightness = (hsl.lightness + (dark ? 0.06 : 0.02))
      .clamp(dark ? 0.22 : 0.68, dark ? 0.38 : 0.82)
      .toDouble();
  final bottomLightness = (topLightness - 0.16)
      .clamp(dark ? 0.16 : 0.5, dark ? 0.34 : 0.7)
      .toDouble();
  return <Color>[
    HSLColor.fromAHSL(1, hue, saturation, topLightness).toColor(),
    HSLColor.fromAHSL(1, hue, saturation * 0.92, bottomLightness).toColor(),
  ];
}

class _SakuraMark extends StatelessWidget {
  const _SakuraMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SakuraMarkPainter(Theme.of(context).colorScheme.primary),
    );
  }
}

class _SakuraMarkPainter extends CustomPainter {
  const _SakuraMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.34;
    final paint = Paint()..color = color;
    for (var index = 0; index < 5; index++) {
      final angle = -math.pi / 2 + index * math.pi * 2 / 5;
      final petalCenter =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.56;
      canvas.save();
      canvas.translate(petalCenter.dx, petalCenter.dy);
      canvas.rotate(angle + math.pi / 2);
      final path = Path()
        ..moveTo(0, -radius * 0.56)
        ..cubicTo(
          radius * 0.42,
          -radius * 0.42,
          radius * 0.42,
          radius * 0.18,
          0,
          radius * 0.36,
        )
        ..cubicTo(
          -radius * 0.42,
          radius * 0.18,
          -radius * 0.42,
          -radius * 0.42,
          0,
          -radius * 0.56,
        );
      canvas.drawPath(path, paint);
      canvas.restore();
    }
    canvas.drawCircle(center, radius * 0.12, paint);
  }

  @override
  bool shouldRepaint(_SakuraMarkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// 地址输入框左侧内嵌的协议（http/https）选择器，点击弹出下拉切换。
class _ProtocolPrefix extends StatefulWidget {
  const _ProtocolPrefix({
    required this.protocol,
    required this.enabled,
    required this.onChanged,
  });

  final String protocol;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_ProtocolPrefix> createState() => _ProtocolPrefixState();
}

class _ProtocolPrefixState extends State<_ProtocolPrefix> {
  static const List<String> _protocols = <String>['http', 'https'];

  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  bool _isMenuOpen = false;

  @override
  void dispose() {
    _removeOverlay(notify: false);
    super.dispose();
  }

  void _toggleMenu() {
    if (!widget.enabled) {
      return;
    }
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }
    _showOverlay();
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);
    final triggerBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (triggerBox == null) {
      return;
    }
    final triggerHeight = triggerBox.size.height;
    // 触发器较窄，菜单需要足够宽度容纳 “https://”，故取触发器宽度与最小宽度的较大值。
    final menuWidth = math.max(triggerBox.size.width, 132.0);
    final formTokens = context.appFormTokens;

    setState(() {
      _isMenuOpen = true;
    });

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, triggerHeight + formTokens.menuGap),
              child: Material(
                color: Colors.transparent,
                child: _ProtocolMenu(
                  width: menuWidth,
                  protocols: _protocols,
                  selected: widget.protocol,
                  onSelected: (protocol) {
                    widget.onChanged(protocol);
                    _removeOverlay();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay({bool notify = true}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (!notify || !mounted) {
      return;
    }
    setState(() {
      _isMenuOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          key: const Key('login-protocol-selector'),
          onTap: _toggleMenu,
          behavior: HitTestBehavior.opaque,
          child: Row(
            key: _triggerKey,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${widget.protocol}://',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  tone: AppTextTone.secondary,
                ),
              ),
              Icon(
                _isMenuOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: context.appComponentTokens.iconSizeSm,
                color: context.appTextPalette.secondary,
              ),
              SizedBox(width: spacing.sm),
              Container(width: 1, height: 20, color: colors.borderSubtle),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtocolMenu extends StatelessWidget {
  const _ProtocolMenu({
    required this.width,
    required this.protocols,
    required this.selected,
    required this.onSelected,
  });

  final double width;
  final List<String> protocols;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final overlayTokens = context.appOverlayTokens;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.smBorder,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.appTextPalette.primary.withValues(
              alpha: overlayTokens.hoverAlpha,
            ),
            blurRadius: overlayTokens.surfaceShadowBlur,
            offset: Offset(0, overlayTokens.surfaceShadowOffsetY),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: context.appRadius.smBorder,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: protocols
              .map(
                (protocol) => _ProtocolMenuItem(
                  protocol: protocol,
                  selected: protocol == selected,
                  onTap: () => onSelected(protocol),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _ProtocolMenuItem extends StatefulWidget {
  const _ProtocolMenuItem({
    required this.protocol,
    required this.selected,
    required this.onTap,
  });

  final String protocol;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ProtocolMenuItem> createState() => _ProtocolMenuItemState();
}

class _ProtocolMenuItemState extends State<_ProtocolMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final formTokens = context.appFormTokens;
    final backgroundColor = widget.selected
        ? colors.surfaceMuted
        : _isHovered
        ? colors.sidebarHoverBackground
        : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        key: Key('login-protocol-${widget.protocol}'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: formTokens.menuItemHeight,
          padding: EdgeInsets.symmetric(
            horizontal: formTokens.fieldHorizontalPadding,
          ),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: backgroundColor),
          child: Text(
            '${widget.protocol}://',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              tone: widget.selected ? AppTextTone.accent : AppTextTone.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 登录页语言切换：首次登录即可选英文，登录失败提示也使用同一语言。
class _LoginLanguageSwitcher extends StatelessWidget {
  const _LoginLanguageSwitcher({
    required this.current,
    required this.enabled,
    required this.onSelected,
  });

  final AppLanguage current;
  final bool enabled;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    return PopupMenuTheme(
      data: PopupMenuThemeData(
        color: context.appColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: context.appRadius.mdBorder,
          side: BorderSide(color: context.appColors.divider),
        ),
        menuPadding: EdgeInsets.symmetric(
          horizontal: spacing.xs,
          vertical: spacing.xs,
        ),
      ),
      child: PopupMenuButton<AppLanguage>(
        key: const Key('login-language-switcher'),
        enabled: enabled,
        tooltip: l10n.settingsLanguageTitle,
        borderRadius: context.appRadius.smBorder,
        clipBehavior: Clip.antiAlias,
        onSelected: onSelected,
        itemBuilder: (context) => <PopupMenuEntry<AppLanguage>>[
          PopupMenuItem<AppLanguage>(
            value: AppLanguage.zhCN,
            child: Text(l10n.settingsLanguageSimplifiedChinese),
          ),
          PopupMenuItem<AppLanguage>(
            value: AppLanguage.en,
            child: Text(l10n.settingsLanguageEnglish),
          ),
        ],
        child: SizedBox(
          height: kMinInteractiveDimension,
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: spacing.sm + spacing.xs,
                vertical: spacing.xs + 2,
              ),
              decoration: BoxDecoration(
                color: context.appColors.surfaceElevated.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.16
                      : 0.68,
                ),
                borderRadius: context.appRadius.pillBorder,
                border: Border.all(color: context.appColors.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.language_rounded,
                    size: context.appComponentTokens.iconSizeSm,
                    color: context.appTextPalette.muted,
                  ),
                  SizedBox(width: spacing.xs),
                  Text(
                    current == AppLanguage.en
                        ? l10n.settingsLanguageEnglish
                        : l10n.settingsLanguageSimplifiedChinese,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: context.appComponentTokens.iconSizeSm,
                    color: context.appTextPalette.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
