import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/announcements/presentation/announcement_link_opener.dart';
import 'package:sakuramedia/features/announcements/presentation/providers/announcement_feed_provider.dart';
import 'package:sakuramedia/features/announcements/presentation/widgets/critical_announcements_dialog.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

class CriticalAnnouncementHost extends ConsumerStatefulWidget {
  const CriticalAnnouncementHost({
    super.key,
    required this.sessionStore,
    required this.navigatorKey,
    required this.isLoginPage,
    required this.child,
  });

  final SessionStore sessionStore;
  final GlobalKey<NavigatorState> navigatorKey;
  final bool Function() isLoginPage;
  final Widget child;

  @override
  ConsumerState<CriticalAnnouncementHost> createState() =>
      _CriticalAnnouncementHostState();
}

class _CriticalAnnouncementHostState
    extends ConsumerState<CriticalAnnouncementHost> {
  late SessionStore _sessionStore;
  late bool _wasAuthenticated;
  Timer? _refreshTimer;
  bool _isShowing = false;
  bool _checkScheduled = false;
  bool _loginRetryScheduled = false;
  int _loginRetryCount = 0;

  @override
  void initState() {
    super.initState();
    _bindSessionStore();
    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      unawaited(ref.read(announcementFeedProvider.notifier).load());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_sessionStore.hasSession) {
        unawaited(ref.read(announcementFeedProvider.notifier).load());
      }
      _scheduleCheck();
    });
  }

  @override
  void didUpdateWidget(covariant CriticalAnnouncementHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionStore == widget.sessionStore) {
      return;
    }
    oldWidget.sessionStore.removeListener(_handleSessionChanged);
    _bindSessionStore();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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
    if (isAuthenticated && !_wasAuthenticated) {
      unawaited(ref.read(announcementFeedProvider.notifier).load());
    } else if (!isAuthenticated && _wasAuthenticated) {
      _loginRetryCount = 0;
      ref.read(announcementFeedProvider.notifier).reset();
    }
    _wasAuthenticated = isAuthenticated;
  }

  void _scheduleCheck() {
    if (_checkScheduled || _isShowing || !mounted) {
      return;
    }
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (mounted) {
        unawaited(_showCriticalIfNeeded());
      }
    });
  }

  Future<void> _showCriticalIfNeeded() async {
    if (_isShowing || !_sessionStore.hasSession || !mounted) {
      return;
    }
    if (widget.isLoginPage()) {
      if (_loginRetryCount >= 30 || _loginRetryScheduled) {
        return;
      }
      _loginRetryCount += 1;
      _loginRetryScheduled = true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      _loginRetryScheduled = false;
      if (mounted) {
        unawaited(_showCriticalIfNeeded());
      }
      return;
    }
    _loginRetryCount = 0;
    final announcements = ref
        .read(announcementFeedProvider)
        .criticalUnacknowledged;
    if (announcements.isEmpty) {
      return;
    }
    final overlayContext = widget.navigatorKey.currentState?.overlay?.context;
    if (overlayContext == null) {
      return;
    }

    _isShowing = true;
    final ids = announcements
        .map((announcement) => announcement.id)
        .toList(growable: false);
    try {
      await showAppAdaptiveModal<void>(
        context: overlayContext,
        modalKey: const Key('critical-announcements-dialog'),
        desktopWidth: 520,
        mobileHeightFactor: 0.42,
        barrierDismissible: false,
        enableDrag: false,
        showDesktopCloseButton: false,
        showDrawerHandle: false,
        builder: (_) => CriticalAnnouncementsDialog(
          announcements: announcements,
          onAcknowledge: () async {
            await ref
                .read(announcementFeedProvider.notifier)
                .acknowledgeCritical(ids);
          },
          onOpenLink: (url) => openAnnouncementLink(overlayContext, ref, url),
        ),
      );
    } finally {
      _isShowing = false;
      if (mounted) {
        _scheduleCheck();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AnnouncementFeedState>(announcementFeedProvider, (_, next) {
      if (next.criticalUnacknowledged.isNotEmpty) {
        _scheduleCheck();
      }
    });
    final feed = ref.watch(announcementFeedProvider);
    if (feed.criticalUnacknowledged.isNotEmpty) {
      _scheduleCheck();
    }
    return widget.child;
  }
}
