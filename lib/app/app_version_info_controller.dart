import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';

typedef AppPackageInfoLoader = Future<PackageInfo> Function();

Future<PackageInfo> _loadPackageInfo() => PackageInfo.fromPlatform();

class AppVersionInfoController extends ChangeNotifier {
  AppVersionInfoController({
    required StatusApi statusApi,
    AppPackageInfoLoader packageInfoLoader = _loadPackageInfo,
  }) : _statusApi = statusApi,
       _packageInfoLoader = packageInfoLoader;

  final StatusApi _statusApi;
  final AppPackageInfoLoader _packageInfoLoader;

  Future<void>? _loadFuture;
  String _frontendVersion = '';
  String _backendVersion = '';

  String get frontendVersionLabel => _versionOrPlaceholder(_frontendVersion);
  String get backendVersionLabel => _versionOrPlaceholder(_backendVersion);
  String get tooltipLabel =>
      '客户端 $frontendVersionLabel · 服务端 $backendVersionLabel';

  Future<void> load() {
    return _loadFuture ??= _loadVersions();
  }

  Future<void> _loadVersions() async {
    await Future.wait<void>([_loadFrontendVersion(), _loadBackendVersion()]);
    notifyListeners();
  }

  Future<void> _loadFrontendVersion() async {
    try {
      final packageInfo = await _packageInfoLoader();
      _frontendVersion = packageInfo.version.trim();
    } catch (_) {
      _frontendVersion = '';
    }
  }

  Future<void> _loadBackendVersion() async {
    try {
      final status = await _statusApi.getStatus();
      _backendVersion = status.backendVersion.trim();
    } catch (_) {
      _backendVersion = '';
    }
  }

  String _versionOrPlaceholder(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '--' : trimmed;
  }
}
