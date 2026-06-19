/// 排行榜列表的本地排序方式。
///
/// 榜单数据一次性全量拉回后在前端排序，不再依赖后端翻页。
/// [byRank] 保持榜单原始名次顺序；[heatDesc]/[heatAsc] 按热度降/升序，
/// 热度相同时回退到名次保持稳定顺序。
enum RankingSortMode { byRank, heatDesc, heatAsc }

extension RankingSortModeX on RankingSortMode {
  /// 是否为「按热度」排序（升序或降序）。
  bool get isByHeat =>
      this == RankingSortMode.heatDesc || this == RankingSortMode.heatAsc;
}
