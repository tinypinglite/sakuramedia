import 'package:sakuramedia/features/overview/presentation/providers/overview_system_info_state.dart';

/// 系统概览的纯展示格式化(迁移前挂在 `OverviewSystemInfoController` 上的
/// 4 个方法;不含状态,widget 侧直接调用)。

String formatGigabytes(int bytes) {
  const bytesPerGigabyte = 1024 * 1024 * 1024;
  final value = bytes <= 0 ? 0.0 : bytes / bytesPerGigabyte;
  return '${value.toStringAsFixed(1)} GB';
}

extension OverviewSystemInfoFormat on OverviewSystemInfoState {
  String buildEmbeddingServiceHealthValue() {
    if (imageSearchStatus == null) {
      return '不可用';
    }
    return imageSearchStatus!.embeddingService.healthy ? '正常' : '异常';
  }

  String buildEmbeddingServiceSpaceValue() {
    final spaceId = imageSearchStatus?.embeddingService.spaceId;
    if (spaceId == null || spaceId.trim().isEmpty) {
      return '未知';
    }
    return spaceId;
  }

  String buildEmbeddingServiceIndexingValue() {
    if (imageSearchStatus == null) {
      return '不可用';
    }
    return imageSearchStatus!.indexing.pendingThumbnails.toString();
  }
}
