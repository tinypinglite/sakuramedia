import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/credential_store.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/auth/data/auth_api.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';

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
  String _protocol = 'http';

  @override
  void initState() {
    super.initState();
    _initBaseUrl(context.read<SessionStore>().baseUrl);
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
    final credentialStore = context.read<CredentialStore>();
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

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    final sessionStore = context.read<SessionStore>();
    final authApi = context.read<AuthApi>();

    try {
      await sessionStore.saveBaseUrl(_composeBaseUrl());
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
        _submitError = apiErrorMessage(error, fallback: '登录失败，请稍后重试');
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
    final host = value?.trim() ?? '';
    if (host.isEmpty) {
      return '请输入服务器地址';
    }
    if (host.contains(RegExp(r'\s'))) {
      return '请输入有效的 http(s) 地址';
    }

    final uri = Uri.tryParse('$_protocol://$host');
    if (uri == null || uri.host.isEmpty) {
      return '请输入有效的 http(s) 地址';
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
                                    style: resolveAppTextStyle(
                                      context,
                                      size: AppTextSize.s18,
                                      weight: AppTextWeight.semibold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: spacing.lg),
                              Text(
                                '登录',
                                style: resolveAppTextStyle(
                                  context,
                                  size: AppTextSize.s14,
                                  weight: AppTextWeight.regular,
                                  tone: AppTextTone.secondary,
                                ),
                              ),
                              SizedBox(height: spacing.sm),
                              Text(
                                '请输入服务器地址与账号信息',
                                style: resolveAppTextStyle(
                                  context,
                                  size: AppTextSize.s14,
                                  tone: AppTextTone.secondary,
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
                                onChanged: _handleBaseUrlChanged,
                                onFieldSubmitted:
                                    (_) => _usernameFocusNode.requestFocus(),
                                hintText: '127.0.0.1:38000',
                                prefix: _ProtocolPrefix(
                                  protocol: _protocol,
                                  enabled: !_isSubmitting,
                                  onChanged: _handleProtocolChanged,
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
                                  color: context.appTextPalette.muted,
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
                                  color: context.appTextPalette.muted,
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
                                    style: resolveAppTextStyle(
                                      context,
                                      size: AppTextSize.s14,
                                      weight: AppTextWeight.regular,
                                      tone: AppTextTone.secondary,
                                    ).copyWith(
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
                                                  style: resolveAppTextStyle(
                                                    context,
                                                    size: AppTextSize.s14,
                                                    tone: AppTextTone.onMedia,
                                                  ),
                                                ),
                                              ],
                                            )
                                            : Text(
                                              '登录',
                                              style: resolveAppTextStyle(
                                                context,
                                                size: AppTextSize.s14,
                                                tone: AppTextTone.onMedia,
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
        cursor:
            widget.enabled
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
          children:
              protocols
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
    final backgroundColor =
        widget.selected
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
