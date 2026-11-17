import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';

/// 标签页选择区的 family 身份。
///
/// 根页面沿用旧缓存 key；从影片详情跳入的预选标签页保留独立、离开即释放的
/// 生命周期，避免将其临时选择覆盖一级入口。
@immutable
class TagSelectionScope {
  const TagSelectionScope._({
    required this.instanceKey,
    this.cacheKey,
    this.initialSelectedTagIds = const <int>[],
    this.initialMatchMode = TagMatchMode.or,
    this.preload = true,
  });

  const TagSelectionScope.desktopRoot()
    : this._(instanceKey: 'desktop:tags:list', cacheKey: 'desktop:tags:list');

  const TagSelectionScope.mobileRoot()
    : this._(instanceKey: 'mobile:tags:list', cacheKey: 'mobile:tags:list');

  const TagSelectionScope.custom({
    required String instanceKey,
    String? cacheKey,
    List<int> initialSelectedTagIds = const <int>[],
    TagMatchMode initialMatchMode = TagMatchMode.or,
    bool preload = true,
  }) : this._(
         instanceKey: instanceKey,
         cacheKey: cacheKey,
         initialSelectedTagIds: initialSelectedTagIds,
         initialMatchMode: initialMatchMode,
         preload: preload,
       );

  TagSelectionScope.desktopDetail({required int initialTagId})
    : this._(
        instanceKey: 'desktop:tags:detail:$initialTagId',
        initialSelectedTagIds: <int>[initialTagId],
      );

  TagSelectionScope.mobileDetail({required int initialTagId})
    : this._(
        instanceKey: 'mobile:tags:detail:$initialTagId',
        initialSelectedTagIds: <int>[initialTagId],
      );

  final String instanceKey;
  final String? cacheKey;
  final List<int> initialSelectedTagIds;
  final TagMatchMode initialMatchMode;

  /// 构建时是否立即拉取全量标签。标签页依赖它保证面板打开即有数据；
  /// 影片库等把目录标签作为附加筛选的页面传 `false`，等面板真正打开再加载。
  final bool preload;

  @override
  bool operator ==(Object other) {
    return other is TagSelectionScope &&
        other.instanceKey == instanceKey &&
        other.cacheKey == cacheKey &&
        listEquals(other.initialSelectedTagIds, initialSelectedTagIds) &&
        other.initialMatchMode == initialMatchMode &&
        other.preload == preload;
  }

  @override
  int get hashCode => Object.hash(
    instanceKey,
    cacheKey,
    Object.hashAll(initialSelectedTagIds),
    initialMatchMode,
    preload,
  );
}
