import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/network/providers/api_client_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

bool supportsNetworkPermissionHint(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => true,
    _ => false,
  };
}

/// 在连接失败时提醒用户检查应用联网权限。
///
/// 客户端更新后，部分系统可能重置本地网络权限。这里只订阅连接失败，
/// 且弹窗展示期间和关闭后一分钟内不重复提示。
class NetworkPermissionHintHost extends ConsumerStatefulWidget {
  const NetworkPermissionHintHost({
    super.key,
    required this.platform,
    required this.navigatorKey,
    required this.child,
    this.failureStream,
    this.targetPlatform,
  });

  final AppPlatform platform;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  /// 测试注入；生产为 `null`，改订阅全局 `ApiClient` 的连接失败事件。
  final Stream<ApiException>? failureStream;

  /// 测试注入；生产为 `null`，使用 [defaultTargetPlatform]。
  final TargetPlatform? targetPlatform;

  @override
  ConsumerState<NetworkPermissionHintHost> createState() =>
      _NetworkPermissionHintHostState();
}

class _NetworkPermissionHintHostState
    extends ConsumerState<NetworkPermissionHintHost> {
  static const Duration _repeatCooldown = Duration(minutes: 1);

  StreamSubscription<ApiException>? _failureSubscription;
  bool _isShowing = false;
  DateTime? _lastShownAt;

  @override
  void initState() {
    super.initState();
    if (kIsWeb || !supportsNetworkPermissionHint(_targetPlatform)) {
      return;
    }
    final failures =
        widget.failureStream ?? ref.read(apiClientProvider).connectionFailures;
    _failureSubscription = failures.listen(_handleConnectionFailure);
  }

  TargetPlatform get _targetPlatform =>
      widget.targetPlatform ?? defaultTargetPlatform;

  @override
  void dispose() {
    unawaited(_failureSubscription?.cancel());
    super.dispose();
  }

  void _handleConnectionFailure(ApiException error) {
    if (!mounted ||
        _isShowing ||
        error.transportFailureKind != ApiTransportFailureKind.connection) {
      return;
    }
    final now = DateTime.now();
    final lastShownAt = _lastShownAt;
    if (lastShownAt != null && now.difference(lastShownAt) < _repeatCooldown) {
      return;
    }

    _isShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_showHint());
    });
    // addPostFrameCallback 不会主动请求新帧，网络事件可能落在两帧之间。
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _showHint() async {
    final overlayContext = widget.navigatorKey.currentState?.overlay?.context;
    if (!mounted || overlayContext == null) {
      _isShowing = false;
      return;
    }

    _lastShownAt = DateTime.now();
    try {
      await showAppAdaptiveModal<void>(
        context: overlayContext,
        modalKey: const Key('network-permission-hint'),
        desktopWidth: 440,
        mobileMaxHeightFactor: 0.56,
        variant: widget.platform == AppPlatform.mobile
            ? AppAdaptiveModalVariant.drawer
            : AppAdaptiveModalVariant.dialog,
        builder: (_) => _NetworkPermissionHint(targetPlatform: _targetPlatform),
      );
    } finally {
      if (mounted) {
        _isShowing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NetworkPermissionHint extends StatelessWidget {
  const _NetworkPermissionHint({required this.targetPlatform});

  final TargetPlatform targetPlatform;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final message = targetPlatform == TargetPlatform.android
        ? l10n.networkPermissionHintAndroidMessage
        : l10n.networkPermissionHintAppleMessage;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppNoticeCard(
          key: const Key('network-permission-hint-content'),
          leadingIcon: Icons.wifi_off_rounded,
          title: l10n.networkPermissionHintTitle,
          description: message,
        ),
        SizedBox(height: spacing.lg),
        AppButton(
          key: const Key('network-permission-hint-dismiss'),
          label: l10n.networkPermissionHintDismiss,
          variant: AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
