import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';

class OverviewSystemInfoController extends ChangeNotifier {
  OverviewSystemInfoController({
    required StatusApi statusApi,
  }) : _statusApi = statusApi;

  final StatusApi _statusApi;

  bool _isDisposed = false;

  bool isLoadingStatus = true;
  bool isLoadingImageSearchStatus = true;
  bool isTestingMetadataProviders = false;
  bool isTestingCloud115Authentication = false;
  bool cloud115AuthenticationRequestFailed = false;
  StatusDto? status;
  StatusImageSearchDto? imageSearchStatus;
  StatusCloud115CookiesDto? cloud115CookiesStatus;
  bool? javdbHealthy;
  bool? dmmHealthy;
  String? statusError;

  Future<void> load() async {
    await Future.wait<void>([
      loadStatus(),
      loadImageSearchStatus(),
    ]);
  }

  Future<void> refresh() async {
    isLoadingStatus = true;
    isLoadingImageSearchStatus = true;
    statusError = null;
    _notifyListenersSafely();
    await load();
  }

  Future<void> loadStatus() async {
    try {
      final nextStatus = await _statusApi.getStatus();
      if (_isDisposed) return;
      status = nextStatus;
      statusError = null;
    } catch (_) {
      if (_isDisposed) return;
      statusError = '系统信息加载失败，请稍后重试';
    } finally {
      if (!_isDisposed) {
        isLoadingStatus = false;
        _notifyListenersSafely();
      }
    }
  }

  Future<void> loadImageSearchStatus() async {
    try {
      final next = await _statusApi.getImageSearchStatus();
      if (_isDisposed) return;
      imageSearchStatus = next;
    } catch (_) {
      if (_isDisposed) return;
      imageSearchStatus = null;
    } finally {
      if (!_isDisposed) {
        isLoadingImageSearchStatus = false;
        _notifyListenersSafely();
      }
    }
  }

  Future<void> testExternalDataSources() async {
    if (isTestingMetadataProviders) {
      return;
    }

    isTestingMetadataProviders = true;
    _notifyListenersSafely();

    final results = await Future.wait<bool>([
      _testMetadataProvider('javdb'),
      _testMetadataProvider('dmm'),
    ]);

    if (_isDisposed) return;
    javdbHealthy = results[0];
    dmmHealthy = results[1];
    isTestingMetadataProviders = false;
    _notifyListenersSafely();
  }

  Future<void> testCloud115Authentication() async {
    if (isTestingCloud115Authentication) {
      return;
    }

    isTestingCloud115Authentication = true;
    cloud115AuthenticationRequestFailed = false;
    cloud115CookiesStatus = null;
    _notifyListenersSafely();

    try {
      final next = await _statusApi.getCloud115CookiesStatus();
      if (_isDisposed) return;
      cloud115CookiesStatus = next;
    } catch (_) {
      if (_isDisposed) return;
      cloud115AuthenticationRequestFailed = true;
    } finally {
      if (!_isDisposed) {
        isTestingCloud115Authentication = false;
        _notifyListenersSafely();
      }
    }
  }

  String formatGigabytes(int bytes) {
    const bytesPerGigabyte = 1024 * 1024 * 1024;
    final value = bytes <= 0 ? 0.0 : bytes / bytesPerGigabyte;
    return '${value.toStringAsFixed(1)} GB';
  }

  String buildJoyTagHealthValue() {
    if (imageSearchStatus == null) {
      return '不可用';
    }
    return imageSearchStatus!.joyTag.healthy ? '正常' : '异常';
  }

  String buildJoyTagDeviceValue() {
    final device = imageSearchStatus?.joyTag.usedDevice;
    if (device == null || device.trim().isEmpty) {
      return '未知';
    }
    return device;
  }

  String buildJoyTagIndexingValue() {
    if (imageSearchStatus == null) {
      return '不可用';
    }
    return imageSearchStatus!.indexing.pendingThumbnails.toString();
  }

  Future<bool> _testMetadataProvider(String provider) async {
    try {
      final result = await _statusApi.testMetadataProvider(provider);
      return result.healthy;
    } catch (_) {
      return false;
    }
  }

  void _notifyListenersSafely() {
    if (_isDisposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
