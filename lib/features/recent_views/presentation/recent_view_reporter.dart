import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/recent_views/data/dto/recent_view_dto.dart';
import 'package:sakuramedia/features/recent_views/presentation/providers/recent_views_api_provider.dart';
import 'package:sakuramedia/features/recent_views/presentation/providers/recent_views_provider.dart';

/// 详情页浏览上报：fire-and-forget，失败静默。
///
/// 浏览记录不是关键路径，只由页面驱动的详情加载 / 手势刷新成功路径触发；
/// 播放器、检查器、订阅切换等不经过详情页的路径不触发。
///
/// 上报成功后 invalidate 列表：概览 rail 所在的页面常驻，不主动刷新的话
/// 跨页浏览后「最近浏览」会一直停留在旧快照。列表无人监听时 invalidate
/// 只是让下次创建时重新拉取，不产生额外请求。
void reportRecentView(
  Ref ref, {
  required RecentViewEntityType entityType,
  required int entityId,
}) {
  if (entityId <= 0) {
    return;
  }
  unawaited(_recordAndInvalidate(ref, entityType, entityId));
}

Future<void> _recordAndInvalidate(
  Ref ref,
  RecentViewEntityType entityType,
  int entityId,
) async {
  try {
    await ref
        .read(recentViewsApiProvider)
        .record(entityType: entityType, entityId: entityId);
  } catch (_) {
    return;
  }
  if (ref.mounted) {
    ref.invalidate(recentViewsProvider);
  }
}
