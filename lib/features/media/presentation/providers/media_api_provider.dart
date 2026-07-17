import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/configuration/data/api/media_libraries_api.dart';
import 'package:sakuramedia/features/media/data/media_api.dart';

part 'media_api_provider.g.dart';

/// media feature 内所有 Riverpod Notifier 读 API 的统一入口。
///
/// body 抛 [UnimplementedError]，实际实例由 `lib/app/app.dart` 的组合根
/// 用 `overrideWithValue(context.read<MediaApi>())` 注入（R2 过渡期方案：
/// legacy MultiProvider 里的 `MediaApi` 单例桥接到 Riverpod 侧）。
@Riverpod(keepAlive: true)
MediaApi mediaApi(Ref ref) {
  throw UnimplementedError('Override mediaApiProvider at the app root');
}

/// media 页需要读媒体库列表（用于筛选、秒传目标选择、存储描述解析）。
///
/// `MediaLibrariesApi` 归属 configuration 域，但目前该域尚未开始 R2 迁移；
/// 先在 media 侧建 bridge，供 [mediaLibrariesProvider] 消费。等 configuration
/// 迁 Riverpod 时把 bridge 上移到 configuration/presentation/providers/。
@Riverpod(keepAlive: true)
MediaLibrariesApi mediaLibrariesApi(Ref ref) {
  throw UnimplementedError(
    'Override mediaLibrariesApiProvider at the app root',
  );
}
