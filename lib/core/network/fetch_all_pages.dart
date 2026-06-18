import 'package:sakuramedia/core/network/paginated_response_dto.dart';

/// 并发翻页拉取**全部**条目：先取第 1 页拿 `total`，其余页按并发上限 [concurrency] 开窗
/// `Future.wait`（批内保序、批次按页序拼接），墙钟从串行的 O(N) 降到 ~O(N/并发)。
///
/// [fetchPage] 按页号拉一页（调用方在闭包里捕获 collectionId/sort/pageSize 等参数，且
/// **闭包内的 page_size 必须与 [pageSize] 一致**，否则 `lastPage` 估算会错）。
/// [extractItems] 从每页响应取出目标条目（如 `page.items` 或 `page.items.map((e) => e.clip)`）。
/// [keyOf] 可选去重键：并发翻页期间集合被并发增删会令页窗口错位、产生跨页重复项，提供
/// [keyOf] 时按出现顺序去重（保留首次出现）。
///
/// 注意：`lastPage` 取自**首页** `total`，翻页期间 `total` 变化不再纠正——加载是一次性快照
/// 操作，可接受短暂不一致；跨页重复由 [keyOf] 兜底。
Future<List<TItem>> fetchAllPagesConcurrently<TItem, TPage>({
  required Future<PaginatedResponseDto<TPage>> Function(int page) fetchPage,
  required Iterable<TItem> Function(PaginatedResponseDto<TPage> page)
  extractItems,
  int pageSize = 50,
  int concurrency = 6,
  Object Function(TItem item)? keyOf,
}) async {
  assert(pageSize > 0, 'pageSize 必须为正');
  assert(concurrency > 0, 'concurrency 必须为正');
  final effectivePageSize = pageSize < 1 ? 1 : pageSize;
  final effectiveConcurrency = concurrency < 1 ? 1 : concurrency;

  final first = await fetchPage(1);
  final result = <TItem>[...extractItems(first)];
  if (result.length >= first.total || first.items.isEmpty) {
    return _dedup(result, keyOf);
  }
  final lastPage = (first.total / effectivePageSize).ceil();
  for (var start = 2; start <= lastPage; start += effectiveConcurrency) {
    final batch = <Future<PaginatedResponseDto<TPage>>>[];
    for (
      var page = start;
      page < start + effectiveConcurrency && page <= lastPage;
      page++
    ) {
      batch.add(fetchPage(page));
    }
    for (final page in await Future.wait(batch)) {
      result.addAll(extractItems(page));
    }
  }
  return _dedup(result, keyOf);
}

List<T> _dedup<T>(List<T> items, Object Function(T item)? keyOf) {
  if (keyOf == null) {
    return items;
  }
  final seen = <Object>{};
  final out = <T>[];
  for (final item in items) {
    if (seen.add(keyOf(item))) {
      out.add(item);
    }
  }
  return out;
}
