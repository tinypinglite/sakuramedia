import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';

class OverviewSystemInfoController extends ChangeNotifier {
  OverviewSystemInfoController({
    required StatusApi statusApi,
  }) : _statusApi = statusApi;

  final StatusApi _statusApi;

  bool isLoadingStatus = true;
  bool isLoadingImageSearchStatus = true;
  bool isTestingMetadataProviders = false;
  StatusDto? status;
  StatusImageSearchDto? imageSearchStatus;
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
}
