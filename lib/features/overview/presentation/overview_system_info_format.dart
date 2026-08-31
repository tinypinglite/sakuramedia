import 'package:sakuramedia/features/overview/presentation/providers/overview_system_info_state.dart';

/// 系统概览的纯展示格式化(迁移前挂在 `OverviewSystemInfoController` 上的
/// 4 个方法;不含状态,widget 侧直接调用)。

String formatGigabytes(int bytes) {
  const bytesPerGigabyte = 1024 * 1024 * 1024;
  final value = bytes <= 0 ? 0.0 : bytes / bytesPerGigabyte;
  return '${value.toStringAsFixed(1)} GB';
}

extension OverviewSystemInfoFormat on OverviewSystemInfoState {
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
}
