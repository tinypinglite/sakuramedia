// 把 test/ 下的每个 *_test.dart 聚合进少量 bundle 入口，供全量测试使用。
//
// 背景：flutter test 的编译器是单实例串行队列，每个测试文件都要单独编译并序列化
// 一次完整 dill，且这部分开销不随 -j 降低。测试文件持续增删，固定数量很快会过时；
// 把动态发现的文件聚合进少量入口后，可以显著降低串行编译开销。
//
// 产物不入库(见 .gitignore)，由 scripts/test.sh 每次跑测前重新生成——生成只需要
// tool/test_timings.json 和磁盘上的文件列表，不需要先跑测试，成本不到 1s。这样
// 就不存在「加了 test 文件却忘了重新生成 bundle、导致新测试被静默跳过」这个失败
// 模式，也不会因为 LPT 重新分桶而产生一堆无谓的 diff 和合并冲突。
//
// 用法：
//   dart run tool/gen_test_bundles.dart                          # 用已有的 tool/test_timings.json
//   dart run tool/gen_test_bundles.dart --raw build/xxx.json     # 顺便从 flutter test 的 JSON reporter 输出刷新耗时
//
// 耗时数据用于均衡分桶：全量墙钟 = 最慢的那个 bundle，分桶不均等于白干。
// 新文件没有耗时记录时按体积估，够用；耗时明显漂了再刷新一次：
//   flutter test --file-reporter=json:build/test_timings_raw.json
//   dart run tool/gen_test_bundles.dart --raw build/test_timings_raw.json

import 'dart:convert';
import 'dart:io';

const int bundleCount = 12;
const String bundleDir = 'test_bundles';
const String timingsPath = 'tool/test_timings.json';

void main(List<String> args) {
  final rawIndex = args.indexOf('--raw');
  final quiet = args.contains('--quiet');

  if (rawIndex != -1) {
    if (rawIndex + 1 >= args.length) {
      stderr.writeln('--raw 需要一个文件路径');
      exit(2);
    }
    _refreshTimings(args[rawIndex + 1]);
  }

  final timings = _loadTimings(quiet: quiet);
  final testFiles = _discoverTestFiles();
  if (testFiles.isEmpty) {
    stderr.writeln('test/ 下没有找到任何 *_test.dart');
    exit(2);
  }

  final bundles = _packBundles(testFiles, timings);
  final generated = <String, String>{};
  for (var i = 0; i < bundles.length; i++) {
    final path = '$bundleDir/bundle_${(i + 1).toString().padLeft(2, '0')}_test.dart';
    generated[path] = _renderBundle(bundles[i]);
  }

  _write(generated);
  if (!quiet) _report(bundles, timings, testFiles.length);
}

// ---------------------------------------------------------------- 耗时

/// 从 `flutter test --file-reporter=json:<path>` 的输出里归约出「每个测试文件的
/// 用例总耗时」。跳过 hidden 的 loading 伪用例——那是编译开销，不是测试耗时。
void _refreshTimings(String rawPath) {
  final raw = File(rawPath);
  if (!raw.existsSync()) {
    stderr.writeln('找不到 $rawPath');
    exit(2);
  }

  final suitePaths = <int, String>{};
  final starts = <int, ({int suiteId, int time})>{};
  final totals = <String, int>{};

  for (final line in raw.readAsLinesSync()) {
    if (line.isEmpty) continue;
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } catch (_) {
      continue;
    }
    if (decoded is! Map<String, dynamic>) continue;

    switch (decoded['type']) {
      case 'suite':
        final suite = decoded['suite'] as Map<String, dynamic>;
        suitePaths[suite['id'] as int] = suite['path'] as String;
      case 'testStart':
        final test = decoded['test'] as Map<String, dynamic>;
        starts[test['id'] as int] = (
          suiteId: test['suiteID'] as int,
          time: decoded['time'] as int,
        );
      case 'testDone':
        if (decoded['hidden'] == true) continue;
        final start = starts[decoded['testID'] as int];
        if (start == null) continue;
        final path = suitePaths[start.suiteId];
        if (path == null) continue;
        final rel = _relative(path);
        totals[rel] = (totals[rel] ?? 0) + (decoded['time'] as int) - start.time;
    }
  }

  if (totals.isEmpty) {
    stderr.writeln('$rawPath 里没解析出任何用例耗时,格式对吗?');
    exit(2);
  }

  final sorted = Map.fromEntries(
    totals.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  File(timingsPath)
      .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(sorted)}\n');
  stdout.writeln('已刷新 $timingsPath（${sorted.length} 个文件）');
}

Map<String, int> _loadTimings({bool quiet = false}) {
  final file = File(timingsPath);
  if (!file.existsSync()) {
    if (!quiet) {
      stdout.writeln('提示：$timingsPath 不存在，将按文件大小估算分桶（可能不均）。');
      stdout.writeln('     刷新耗时见 tool/gen_test_bundles.dart 顶部注释。');
    }
    return const {};
  }
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return decoded.map((key, value) => MapEntry(key, (value as num).toInt()));
}

// ---------------------------------------------------------------- 发现与分桶

List<String> _discoverTestFiles() {
  return Directory('test')
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => _relative(file.path))
      .where((path) => path.endsWith('_test.dart'))
      .toList()
    ..sort();
}

/// 没有耗时数据的文件按体积估一个：小文件多半也跑得快，但别估成 0，
/// 否则新增的重测试会全被塞进同一个桶。
int _weightOf(String path, Map<String, int> timings) {
  final known = timings[path];
  if (known != null) return known;
  final size = File(path).lengthSync();
  return (size / 100).round().clamp(50, 20000);
}

/// LPT(最长处理时间优先)贪心：耗时降序，每个文件塞进当前最空的桶。
/// 对这个规模足够接近最优，且结果稳定可复现。
List<List<String>> _packBundles(List<String> files, Map<String, int> timings) {
  final weighted = files
      .map((path) => (path: path, weight: _weightOf(path, timings)))
      .toList()
    // 同耗时按路径排序，保证生成结果是确定的（CI 的 --check 依赖这一点）。
    ..sort((a, b) {
      final byWeight = b.weight.compareTo(a.weight);
      return byWeight != 0 ? byWeight : a.path.compareTo(b.path);
    });

  final bundles = List.generate(bundleCount, (_) => <String>[]);
  final loads = List.filled(bundleCount, 0);

  for (final item in weighted) {
    var lightest = 0;
    for (var i = 1; i < bundleCount; i++) {
      if (loads[i] < loads[lightest]) lightest = i;
    }
    bundles[lightest].add(item.path);
    loads[lightest] += item.weight;
  }

  // 桶内按路径排序，让产物 diff 可读。
  for (final bundle in bundles) {
    bundle.sort();
  }
  return bundles.where((bundle) => bundle.isNotEmpty).toList();
}

// ---------------------------------------------------------------- 产物

/// 每个测试文件的 main() 用 group() 包起来。group 是安全性的关键：
/// 它保留了各文件 setUp/tearDown/late 变量的作用域，不会互相串。
String _renderBundle(List<String> files) {
  final buffer = StringBuffer()
    ..writeln('// GENERATED — 由 tool/gen_test_bundles.dart 生成，请勿手改。')
    ..writeln('// 增删 test 文件后需重新生成：dart run tool/gen_test_bundles.dart')
    ..writeln('//')
    ..writeln('// ignore_for_file: directives_ordering')
    ..writeln()
    ..writeln("import 'package:flutter_test/flutter_test.dart';")
    ..writeln();

  for (var i = 0; i < files.length; i++) {
    buffer.writeln("import '../${files[i]}' as t$i;");
  }

  buffer
    ..writeln()
    ..writeln('void main() {');
  for (var i = 0; i < files.length; i++) {
    // group 名用相对路径，失败信息里能直接定位到源文件。
    final name = files[i].substring('test/'.length);
    buffer.writeln("  group('$name', t$i.main);");
  }
  buffer.writeln('}');
  return buffer.toString();
}

void _write(Map<String, String> generated) {
  final dir = Directory(bundleDir);
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  generated.forEach((path, contents) {
    File(path).writeAsStringSync(contents);
  });
}

void _report(List<List<String>> bundles, Map<String, int> timings, int fileCount) {
  stdout.writeln('已生成 ${bundles.length} 个 bundle，覆盖 $fileCount 个测试文件。');
  var heaviest = 0;
  for (var i = 0; i < bundles.length; i++) {
    final load = bundles[i].fold(0, (sum, p) => sum + _weightOf(p, timings));
    if (load > heaviest) heaviest = load;
    stdout.writeln(
      '  bundle_${(i + 1).toString().padLeft(2, '0')}: '
      '${bundles[i].length.toString().padLeft(3)} 个文件, '
      '约 ${(load / 1000).toStringAsFixed(1)}s',
    );
  }
  stdout.writeln('最重的桶约 ${(heaviest / 1000).toStringAsFixed(1)}s —— 这是全量墙钟的下界。');
}

String _relative(String path) {
  final root = '${Directory.current.path}${Platform.pathSeparator}';
  final normalized = path.startsWith(root) ? path.substring(root.length) : path;
  return normalized.replaceAll(Platform.pathSeparator, '/');
}
