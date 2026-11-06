import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/providers/external_url_provider.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/api/provider_login_api.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_catalog_dto.dart';
import 'package:sakuramedia/features/configuration/data/dto/provider_login_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_login_capture.dart';
import 'package:sakuramedia/features/configuration/presentation/forms/provider_login_session_reset.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/provider_login_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/provider_login_validating_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_spinner.dart';

const _localStorageSnapshotScript = '''
(() => {
  const result = {};
  for (let index = 0; index < localStorage.length; index += 1) {
    const key = localStorage.key(index);
    if (key !== null) result[key] = localStorage.getItem(key);
  }
  return JSON.stringify(result);
})()
''';

const _desktopLoginUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/125.0.0.0 Safari/537.36';

const _desktopLoginFocusScript = '''
(() => {
  const viewportWidth = window.innerWidth;
  const pageWidth = Math.max(
    document.documentElement ? document.documentElement.scrollWidth : 0,
    document.body ? document.body.scrollWidth : 0,
  );
  if (pageWidth <= viewportWidth + 80) return true;
  const isVisible = (element) => {
    const rect = element.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  };
  const inputs = Array.from(document.querySelectorAll(
    'input[type="tel"], input[type="password"], input[type="email"], input[type="text"]',
  )).filter(isVisible);
  inputs.sort((a, b) => b.getBoundingClientRect().x - a.getBoundingClientRect().x);
  let target = inputs[0] || null;
  if (!target) {
    const candidates = Array.from(
      document.querySelectorAll('[id*="login" i], [class*="login" i]'),
    )
      .filter(isVisible)
      .filter((element) => {
        const rect = element.getBoundingClientRect();
        return rect.width >= 240 && rect.width <= 520 && rect.height >= 240;
      });
    candidates.sort(
      (a, b) => b.getBoundingClientRect().right - a.getBoundingClientRect().right,
    );
    target = candidates[0] || null;
  }
  if (!target) return false;
  target.scrollIntoView({block: 'center', inline: 'center'});
  return true;
})()
''';

typedef ProviderLoginLauncher =
    Future<ProviderLoginSessionDto?> Function(
      BuildContext context,
      MediaProviderDto provider,
    );

final providerLoginLauncherProvider = Provider<ProviderLoginLauncher>((ref) {
  return (context, provider) =>
      showProviderLoginPage(context: context, provider: provider);
});

Future<ProviderLoginSessionDto?> showProviderLoginPage({
  required BuildContext context,
  required MediaProviderDto provider,
}) {
  final login = provider.libraryLogin;
  if (login == null || login.mode != 'webview') {
    return Future<ProviderLoginSessionDto?>.value();
  }
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<ProviderLoginSessionDto>(
    MaterialPageRoute<ProviderLoginSessionDto>(
      builder: (_) => ProviderLoginPage(
        providerKey: provider.providerKey,
        displayName: provider.displayName,
        login: login,
      ),
    ),
  );
}

class ProviderLoginPage extends ConsumerStatefulWidget {
  const ProviderLoginPage({
    super.key,
    required this.providerKey,
    required this.displayName,
    required this.login,
  });

  final String providerKey;
  final String displayName;
  final ProviderLoginDto login;

  @override
  ConsumerState<ProviderLoginPage> createState() => _ProviderLoginPageState();
}

class _ProviderLoginPageState extends ConsumerState<ProviderLoginPage> {
  InAppWebViewController? _controller;
  Timer? _pollTimer;
  DateTime? _startedAt;
  String? _lastCaptureSignature;
  String? _error;
  bool _isLoading = true;
  bool _isChecking = false;
  bool _isFocusingLoginPanel = false;
  bool _isClosing = false;
  bool _isPreparingWebView = true;
  bool _isValidatingSession = false;
  bool _allowPop = false;
  double _progress = 0;
  int _webViewGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareWebView());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool _allowed(Uri uri) {
    if (uri.scheme == 'about' && uri.toString() == 'about:blank') {
      return true;
    }
    return isAllowedProviderLoginUri(uri, widget.login.allowedHosts);
  }

  Future<void> _openExternal(Uri uri) async {
    if (uri.scheme != 'http' && uri.scheme != 'https') return;
    await ref.read(externalUrlOpenerProvider)(uri);
  }

  Future<NavigationActionPolicy> _shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = action.request.url;
    if (uri == null) return NavigationActionPolicy.CANCEL;
    if (_allowed(uri)) return NavigationActionPolicy.ALLOW;
    if (isAllowedProviderLoginHttpUri(uri, widget.login.allowedHosts)) {
      return NavigationActionPolicy.CANCEL;
    }
    await _openExternal(uri);
    return NavigationActionPolicy.CANCEL;
  }

  Future<bool> _onCreateWindow(
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    final uri = action.request.url;
    if (uri == null) return false;
    if (_allowed(uri) ||
        isAllowedProviderLoginHttpUri(uri, widget.login.allowedHosts)) {
      await controller.loadUrl(urlRequest: action.request);
      return false;
    }
    await _openExternal(uri);
    return false;
  }

  Future<void> _prepareWebView({bool waitForDisposal = false}) async {
    if (waitForDisposal) {
      await WidgetsBinding.instance.endOfFrame;
    }
    try {
      await resetProviderLoginWebViewSession(widget.login);
    } catch (_) {
      if (!mounted || _isClosing) return;
      setState(() {
        _isPreparingWebView = false;
        _isLoading = false;
        _error = AppLocalizations.of(context).providerLoginSessionResetFailed;
      });
      return;
    }
    if (!mounted || _isClosing) return;
    setState(() {
      _isPreparingWebView = false;
      _webViewGeneration += 1;
      _startedAt = DateTime.now();
      _isLoading = true;
      _error = null;
    });
    _startCapturePolling();
  }

  void _startCapturePolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_checkCapture()),
    );
  }

  Future<void> _checkCapture() async {
    if (_isChecking ||
        _isClosing ||
        _isPreparingWebView ||
        _isValidatingSession ||
        _controller == null ||
        _isLoading ||
        _error != null) {
      return;
    }
    final startedAt = _startedAt;
    if (startedAt != null &&
        DateTime.now().difference(startedAt).inSeconds >
            widget.login.timeoutSeconds) {
      _pollTimer?.cancel();
      if (mounted) {
        setState(() {
          _error = AppLocalizations.of(context).providerLoginTimedOut;
        });
      }
      return;
    }
    _isChecking = true;
    try {
      final currentUrl = await _controller?.getUrl();
      if (!mounted || currentUrl == null) return;
      final cookiesByUrl = await _readCookies();
      final storageByOrigin = await _readLocalStorage(currentUrl);
      if (!mounted ||
          !isProviderLoginCaptureComplete(
            login: widget.login,
            cookiesByUrl: cookiesByUrl,
            localStorageByOrigin: storageByOrigin,
          )) {
        return;
      }
      final payloadCookies = buildProviderLoginCookiePayloads(
        widget.login,
        cookiesByUrl,
      );
      final payloadStorage = buildProviderLoginLocalStoragePayloads(
        widget.login,
        storageByOrigin,
      );
      final signature = jsonEncode(<String, dynamic>{
        'cookies': payloadCookies.map((item) => item.toJson()).toList(),
        'local_storage': payloadStorage.map((item) => item.toJson()).toList(),
      });
      if (signature == _lastCaptureSignature) return;
      _lastCaptureSignature = signature;
      _pollTimer?.cancel();
      final api = ref.read(providerLoginApiProvider);
      setState(() => _isValidatingSession = true);
      final session = await api.createSession(
        providerKey: widget.providerKey,
        cookies: payloadCookies,
        localStorage: payloadStorage,
      );
      if (!mounted || _isClosing) {
        await _discardSession(api, session);
        return;
      }
      await _close(session);
    } catch (error) {
      if (!mounted || _isClosing) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _isValidatingSession = false;
        _error = apiErrorMessage(
          error,
          fallback: l10n.providerLoginFailed,
          l10n: l10n,
        );
      });
      _pollTimer?.cancel();
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _discardSession(
    ProviderLoginApi api,
    ProviderLoginSessionDto session,
  ) async {
    try {
      await api.deleteSession(session.id);
    } catch (_) {
      // The unused login session expires on the server if deletion fails.
    }
  }

  Future<void> _focusLoginPanel() async {
    if (_isFocusingLoginPanel) return;
    _isFocusingLoginPanel = true;
    try {
      for (var attempt = 0; attempt < 10; attempt += 1) {
        final controller = _controller;
        if (!mounted || _isClosing || controller == null) return;
        final result = await controller.evaluateJavascript(
          source: _desktopLoginFocusScript,
        );
        if (result == true || result == 'true') return;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    } catch (_) {
      return;
    } finally {
      _isFocusingLoginPanel = false;
    }
  }

  Future<Map<String, Map<String, String>>> _readCookies() async {
    final controller = _controller;
    if (controller == null) return const <String, Map<String, String>>{};
    final result = <String, Map<String, String>>{};
    for (final capture in widget.login.cookieCaptures) {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(capture.url),
        webViewController: controller,
      );
      result[capture.url] = selectProviderLoginCookies(
        cookies.map((cookie) => (cookie.name, cookie.value)),
        capture.captureNames,
      );
    }
    return result;
  }

  Future<Map<String, Map<String, String>>> _readLocalStorage(
    Uri currentUrl,
  ) async {
    final controller = _controller;
    if (controller == null) return const <String, Map<String, String>>{};
    final result = <String, Map<String, String>>{};
    for (final capture in widget.login.localStorageCaptures) {
      final origin = Uri.tryParse(capture.origin);
      if (origin == null || !_sameOrigin(origin, currentUrl)) continue;
      final raw = await controller.evaluateJavascript(
        source: _localStorageSnapshotScript,
      );
      result[capture.origin] = decodeProviderLoginLocalStorage(raw);
    }
    return result;
  }

  bool _sameOrigin(Uri a, Uri b) {
    return a.scheme == b.scheme && a.host == b.host && a.port == b.port;
  }

  Future<void> _clearLoginData() async {
    final controller = _controller;
    try {
      for (final capture in widget.login.cookieCaptures) {
        await CookieManager.instance().deleteCookies(
          url: WebUri(capture.url),
          webViewController: controller,
        );
      }
      for (final capture in widget.login.localStorageCaptures) {
        final origin = Uri.tryParse(capture.origin);
        final currentUrl = await controller?.getUrl();
        if (origin != null &&
            currentUrl != null &&
            _sameOrigin(origin, currentUrl)) {
          await controller?.evaluateJavascript(
            source: 'localStorage.clear(); sessionStorage.clear();',
          );
        }
      }
    } catch (_) {
      // Best-effort cleanup should not block closing the login page.
    }
  }

  Future<void> _close([ProviderLoginSessionDto? session]) async {
    if (_isClosing) return;
    _isClosing = true;
    _pollTimer?.cancel();
    unawaited(_clearLoginData());
    if (!mounted) return;
    setState(() => _allowPop = true);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    Navigator.of(context).pop(session);
  }

  void _retry() {
    if (_isClosing || _isPreparingWebView || _isValidatingSession) return;
    _pollTimer?.cancel();
    setState(() {
      _controller = null;
      _isPreparingWebView = true;
      _error = null;
      _isLoading = true;
      _isValidatingSession = false;
      _progress = 0;
      _startedAt = null;
      _lastCaptureSignature = null;
    });
    unawaited(_prepareWebView(waitForDisposal: true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final uri = Uri.tryParse(widget.login.startUrl);
    if (uri == null ||
        !isAllowedProviderLoginUri(uri, widget.login.allowedHosts)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.providerLoginTitle(widget.displayName)),
        ),
        body: Center(child: Text(l10n.providerLoginUnavailable)),
      );
    }
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.providerLoginTitle(widget.displayName)),
          leading: IconButton(
            tooltip: l10n.commonClose,
            onPressed: _isClosing ? null : () => unawaited(_close()),
            icon: const Icon(Icons.close_rounded),
          ),
          actions: [
            IconButton(
              tooltip: l10n.commonRetry,
              onPressed:
                  _isClosing || _isPreparingWebView || _isValidatingSession
                  ? null
                  : _retry,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: _progress < 1
                ? LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                  )
                : const SizedBox(height: 2),
          ),
        ),
        body: Stack(
          children: [
            if (_isPreparingWebView)
              const Positioned.fill(child: Center(child: AppInlineSpinner()))
            else if (_error == null)
              InAppWebView(
                key: ValueKey(_webViewGeneration),
                initialUrlRequest: URLRequest(
                  url: WebUri(widget.login.startUrl),
                ),
                initialSettings: InAppWebViewSettings(
                  incognito: defaultTargetPlatform == TargetPlatform.windows,
                  cacheEnabled: false,
                  userAgent: _desktopLoginUserAgent,
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  thirdPartyCookiesEnabled: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  supportMultipleWindows: true,
                  useShouldOverrideUrlLoading: true,
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                },
                onLoadStart: (_, _) {
                  if (mounted) {
                    setState(() {
                      _isLoading = true;
                      _progress = 0;
                    });
                  }
                },
                onProgressChanged: (_, progress) {
                  if (!mounted) return;
                  setState(() {
                    _progress = progress / 100;
                  });
                },
                onLoadStop: (_, _) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                  unawaited(_focusLoginPanel());
                  unawaited(_checkCapture());
                },
                shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
                onCreateWindow: _onCreateWindow,
                onReceivedError: (_, request, error) {
                  if (request.isForMainFrame == true &&
                      error.type != WebResourceErrorType.CANCELLED &&
                      !_isValidatingSession &&
                      mounted) {
                    setState(() {
                      _error = l10n.providerLoginPageLoadFailed;
                      _isLoading = false;
                    });
                  }
                },
              ),
            if (_error == null && !_isPreparingWebView && !_isValidatingSession)
              Positioned(
                left: spacing.md,
                right: spacing.md,
                bottom: spacing.md,
                child: IgnorePointer(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.appColors.surfaceCard.withValues(
                          alpha: 0.94,
                        ),
                        borderRadius: context.appRadius.mdBorder,
                        border: Border.all(
                          color: context.appColors.borderSubtle,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.md,
                          vertical: spacing.sm,
                        ),
                        child: Text(
                          l10n.providerLoginWaitingHint,
                          textAlign: TextAlign.center,
                          style: resolveAppTextStyle(
                            context,
                            size: AppTextSize.s12,
                            tone: AppTextTone.secondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_isValidatingSession)
              Positioned.fill(
                child: ProviderLoginValidatingCard(
                  providerName: widget.displayName,
                ),
              ),
            if (_error != null)
              Positioned.fill(
                child: ColoredBox(
                  color: context.appColors.mediaOverlayStrong,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Material(
                        color: context.appColors.surfaceCard,
                        borderRadius: context.appRadius.lgBorder,
                        child: Padding(
                          padding: EdgeInsets.all(spacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: resolveAppTextStyle(
                                  context,
                                  size: AppTextSize.s14,
                                  tone: AppTextTone.primary,
                                ),
                              ),
                              SizedBox(height: spacing.lg),
                              AppButton(
                                label: l10n.commonRetry,
                                onPressed: _isValidatingSession ? null : _retry,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
