import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_api.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_dto.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';

class OverviewSystemInfoController extends ChangeNotifier {
  OverviewSystemInfoController({
    required StatusApi statusApi,
    required MetadataProviderLicenseApi metadataProviderLicenseApi,
  }) : _statusApi = statusApi,
       _metadataProviderLicenseApi = metadataProviderLicenseApi;

  final StatusApi _statusApi;
  final MetadataProviderLicenseApi _metadataProviderLicenseApi;

  bool isLoadingStatus = true;
  bool isLoadingImageSearchStatus = true;
  bool isLoadingLicenseStatus = true;
  bool isTestingMetadataProviders = false;
  bool isTestingLicenseConnectivity = false;
  StatusDto? status;
  StatusImageSearchDto? imageSearchStatus;
  MetadataProviderLicenseStatusDto? licenseStatus;
  MetadataProviderLicenseConnectivityTestDto? licenseConnectivityTest;
  String? licenseStatusError;
  bool? javdbHealthy;
  bool? dmmHealthy;
  String? statusError;

  Future<void> load() async {
    await Future.wait<void>([
      loadStatus(),
      loadImageSearchStatus(),
      loadLicenseStatus(),
    ]);
  }

  Future<void> refresh() async {
    isLoadingStatus = true;
    isLoadingImageSearchStatus = true;
    isLoadingLicenseStatus = true;
    statusError = null;
    licenseStatusError = null;
    notifyListeners();
    await load();
  }

  Future<void> loadStatus() async {
    try {
      final nextStatus = await _statusApi.getStatus();
      status = nextStatus;
      statusError = null;
    } catch (_) {
      statusError = '系统信息加载失败，请稍后重试';
    } finally {
      isLoadingStatus = false;
      notifyListeners();
    }
  }

  Future<void> loadImageSearchStatus() async {
    try {
      imageSearchStatus = await _statusApi.getImageSearchStatus();
    } catch (_) {
      imageSearchStatus = null;
    } finally {
      isLoadingImageSearchStatus = false;
      notifyListeners();
    }
  }

  Future<void> loadLicenseStatus() async {
    try {
      licenseStatus = await _metadataProviderLicenseApi.getStatus();
      licenseStatusError = null;
    } catch (_) {
      licenseStatus = null;
      licenseStatusError = 'unavailable';
    } finally {
      isLoadingLicenseStatus = false;
      notifyListeners();
    }
  }

  Future<void> testExternalDataSources() async {
    if (isTestingMetadataProviders) {
      return;
    }

    isTestingMetadataProviders = true;
    notifyListeners();

    final results = await Future.wait<bool>([
      _testMetadataProvider('javdb'),
      _testMetadataProvider('dmm'),
    ]);

    javdbHealthy = results[0];
    dmmHealthy = results[1];
    isTestingMetadataProviders = false;
    notifyListeners();
  }

  Future<void> testLicenseConnectivity() async {
    if (isTestingLicenseConnectivity) {
      return;
    }

    isTestingLicenseConnectivity = true;
    notifyListeners();

    try {
      licenseConnectivityTest =
          await _metadataProviderLicenseApi.testConnectivity();
    } catch (_) {
      licenseConnectivityTest =
          const MetadataProviderLicenseConnectivityTestDto(
            ok: false,
            url: '',
            proxyEnabled: false,
            elapsedMs: 0,
            error: 'unavailable',
          );
    } finally {
      isTestingLicenseConnectivity = false;
      notifyListeners();
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

  String buildLicenseStatusValue() {
    if (licenseStatusError != null) {
      return '不可用';
    }
    final status = licenseStatus;
    if (status == null) {
      return '不可用';
    }
    if (status.active) {
      return '已激活';
    }
    final errorCode = status.errorCode?.trim();
    if (errorCode == 'license_expired' ||
        _isUnixSecondsExpired(status.licenseValidUntil)) {
      return '授权已到期';
    }
    if (status.licenseValidUntil != null) {
      return '授权待同步';
    }
    if (status.configured && errorCode != null && errorCode.isNotEmpty) {
      return _licenseErrorLabel(errorCode);
    }
    return '未激活';
  }

  String buildLicenseConnectivityValue() {
    if (isTestingLicenseConnectivity) {
      return '检测中';
    }
    final result = licenseConnectivityTest;
    if (result == null) {
      return '未检测';
    }
    return result.ok ? '连接正常' : '连接异常';
  }

  String buildExternalDataSourcesValue() {
    if (isTestingMetadataProviders) {
      return '检测中';
    }
    if (javdbHealthy == null && dmmHealthy == null) {
      return '未检测 JavDB / DMM';
    }
    return '${_buildExternalDataSourceText('JavDB', javdbHealthy)} ${_buildExternalDataSourceText('DMM', dmmHealthy)}';
  }

  Future<bool> _testMetadataProvider(String provider) async {
    try {
      final result = await _statusApi.testMetadataProvider(provider);
      return result.healthy;
    } catch (_) {
      return false;
    }
  }

  String _buildExternalDataSourceText(String label, bool? healthy) {
    if (healthy == null) {
      return '未检测 $label';
    }
    return '${healthy ? '✅' : '❌'} $label';
  }

  bool _isUnixSecondsExpired(int? unixSeconds) {
    if (unixSeconds == null) {
      return false;
    }
    final value = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    );
    return value.isBefore(DateTime.now().toUtc());
  }

  String _licenseErrorLabel(String errorCode) {
    return switch (errorCode) {
      'license_required' => '未激活',
      'license_expired' => '授权已到期',
      'license_revoked' => '授权已吊销',
      'license_unavailable' => '授权不可用',
      _ => errorCode,
    };
  }
}
