/// 本地影片列表返回的是模糊搜索结果，必须再按番号做精确匹配。
///
/// 规则镜像后端 `MovieService._number_search_target`：
/// - 普通番号去掉 `-` / `_` 后比较，并折叠 `FC2PPV` → `FC2`；
/// - 纯数字番号保留分隔符，`123456-789` 与 `123456_789` 是不同影片。
bool isExactMovieNumberMatch({
  required String storedMovieNumber,
  required String query,
}) {
  final normalizedQuery = query.trim().toUpperCase();
  if (normalizedQuery.isEmpty) return false;
  final stored = storedMovieNumber.trim().toUpperCase();

  if (RegExp(r'^\d+[-_]\d+$').hasMatch(normalizedQuery)) {
    return stored == normalizedQuery;
  }

  String fold(String value) =>
      value.replaceAll('-', '').replaceAll('_', '').replaceAll('FC2PPV', 'FC2');

  final key = fold(normalizedQuery);
  return key.isNotEmpty && fold(stored) == key;
}
