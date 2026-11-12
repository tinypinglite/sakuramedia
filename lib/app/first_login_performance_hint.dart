import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/onboarding_store.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 在会话从「未登录」变为「已登录」时展示一次性能提示。
///
/// 启动时已经带会话不会触发，因此不会每次启动都打扰用户。
class FirstLoginPerformanceHintHost extends StatefulWidget {
  const FirstLoginPerformanceHintHost({
    super.key,
    required this.sessionStore,
    required this.onboardingStore,
    required this.platform,
    required this.navigatorKey,
    required this.isLoginPage,
    this.shouldSuppress,
    required this.child,
  });

  final SessionStore sessionStore;
  final OnboardingStore onboardingStore;
  final AppPlatform platform;
  final GlobalKey<NavigatorState> navigatorKey;
  final bool Function() isLoginPage;
  final bool Function()? shouldSuppress;
  final Widget child;

  @override
  State<FirstLoginPerformanceHintHost> createState() =>
      _FirstLoginPerformanceHintHostState();
}

class _FirstLoginPerformanceHintHostState
    extends State<FirstLoginPerformanceHintHost> {
  late SessionStore _sessionStore;
  late bool _wasAuthenticated;

  @override
  void initState() {
    super.initState();
    _bindSessionStore();
  }

  @override
  void didUpdateWidget(covariant FirstLoginPerformanceHintHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionStore == widget.sessionStore) {
      return;
    }
    oldWidget.sessionStore.removeListener(_handleSessionChanged);
    _bindSessionStore();
  }

  @override
  void dispose() {
    _sessionStore.removeListener(_handleSessionChanged);
    super.dispose();
  }

  void _bindSessionStore() {
    _sessionStore = widget.sessionStore;
    _wasAuthenticated = _sessionStore.hasSession;
    _sessionStore.addListener(_handleSessionChanged);
  }

  void _handleSessionChanged() {
    final isAuthenticated = _sessionStore.hasSession;
    final justAuthenticated = !_wasAuthenticated && isAuthenticated;
    _wasAuthenticated = isAuthenticated;

    if (!justAuthenticated || widget.onboardingStore.hasSeenPerformanceHint) {
      return;
    }

    unawaited(_showHintAfterLogin());
  }

  Future<void> _showHintAfterLogin() async {
    // 等登录页完成跳转，避免提示叠在登录页的退场动画上。
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (var attempt = 0; attempt < 30; attempt++) {
      if (!mounted || !_sessionStore.hasSession) {
        return;
      }
      if (!widget.isLoginPage()) {
        break;
      }
      if (attempt == 29) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted ||
        !_sessionStore.hasSession ||
        widget.onboardingStore.hasSeenPerformanceHint) {
      return;
    }
    for (var attempt = 0; attempt < 60; attempt++) {
      if (!mounted ||
          !_sessionStore.hasSession ||
          widget.onboardingStore.hasSeenPerformanceHint) {
        return;
      }
      if (widget.shouldSuppress?.call() != true) {
        break;
      }
      if (attempt == 59) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    await _showHint();
  }

  Future<void> _showHint() async {
    final overlayContext = widget.navigatorKey.currentState?.overlay?.context;
    if (overlayContext == null) {
      return;
    }

    // 先落盘再展示：即使应用在弹窗期间退出，也不会在下次启动重复打扰。
    await widget.onboardingStore.markPerformanceHintSeen();
    if (!mounted || !overlayContext.mounted) {
      return;
    }
    await showAppAdaptiveModal<void>(
      context: overlayContext,
      modalKey: const Key('first-login-performance-hint'),
      desktopWidth: 420,
      mobileMaxHeightFactor: 0.6,
      variant: widget.platform == AppPlatform.mobile
          ? AppAdaptiveModalVariant.drawer
          : AppAdaptiveModalVariant.dialog,
      builder: (_) => const FirstLoginPerformanceHintDialog(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class FirstLoginPerformanceHintDialog extends StatefulWidget {
  const FirstLoginPerformanceHintDialog({super.key});

  @override
  State<FirstLoginPerformanceHintDialog> createState() =>
      _FirstLoginPerformanceHintDialogState();
}

class _FirstLoginPerformanceHintDialogState
    extends State<FirstLoginPerformanceHintDialog> {
  static const Duration _autoDismissAfter = Duration(seconds: 10);

  Timer? _autoDismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _autoDismissTimer = Timer(_autoDismissAfter, _dismiss);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void _dismiss() {
    if (!mounted || _isDismissing) {
      return;
    }
    _isDismissing = true;
    _autoDismissTimer?.cancel();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppNoticeCard(
          leadingIcon: Icons.speed_rounded,
          title: l10n.firstLoginPerformanceHintTitle,
          description: l10n.firstLoginPerformanceHintDescription,
        ),
        SizedBox(height: spacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            key: const Key('first-login-performance-hint-dismiss'),
            label: l10n.firstLoginPerformanceHintDismiss,
            variant: AppButtonVariant.primary,
            onPressed: _dismiss,
          ),
        ),
      ],
    );
  }
}
