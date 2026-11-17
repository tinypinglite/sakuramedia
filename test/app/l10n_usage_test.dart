import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _arbZhPath = 'lib/l10n/app_zh.arb';
const String _arbEnPath = 'lib/l10n/app_en.arb';
const String _generatedLocalizationsPath = 'lib/l10n/app_localizations.dart';

/// ARB 里声明、但在 `lib/` 中找不到引用的 key 白名单。
///
/// 规则：
/// - 只允许「静态扫描确实无法判定」的极少数 key（例如运行时动态拼接的文案）；
/// - 每一项都要写清楚原因，禁止把大批 key 塞进来绕过守卫；
/// - 常规新增文案不允许出现在这里：要么在代码里用起来，要么从 ARB 删掉。
const Map<String, String> _allowedUnreferencedKeys = <String, String>{
  // 例：'someRuntimeBuiltKey': '运行时按接口返回拼接，无法静态引用',
};

/// `lib/` 下的 Dart 源码，排除 gen-l10n 生成物。
List<File> _dartSourcesUnderLib() {
  final files = <File>[];
  final root = Directory('lib');
  if (!root.existsSync()) {
    return files;
  }
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    if (entity.path.startsWith('lib/l10n/app_localizations')) {
      continue;
    }
    files.add(entity);
  }
  files.sort((File a, File b) => a.path.compareTo(b.path));
  return files;
}

Set<String> _arbKeys(String path) {
  final arb = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return arb.keys
      .where((String key) => !key.startsWith('@'))
      .toSet();
}

void main() {
  test('every ARB key is referenced from lib code', () {
    final arbKeys = <String>{..._arbKeys(_arbZhPath), ..._arbKeys(_arbEnPath)};
    expect(arbKeys, isNotEmpty);

    final sources = _dartSourcesUnderLib()
        .map((File file) => file.readAsStringSync())
        .join('\n');

    final unreferenced = arbKeys
        .where((String key) => !_allowedUnreferencedKeys.containsKey(key))
        .where((String key) => !sources.contains('.$key'))
        .toList()
      ..sort();

    expect(
      unreferenced,
      isEmpty,
      reason: '以下 ARB key 在 lib/ 中找不到引用，请删除或接入代码；'
          '若确实无法静态引用，请补充到 _allowedUnreferencedKeys 并说明原因：'
          '${unreferenced.join(', ')}',
    );

    for (final entry in _allowedUnreferencedKeys.entries) {
      expect(
        arbKeys.contains(entry.key),
        isTrue,
        reason: '白名单里的 ${entry.key} 已经不在 ARB 中，请移除白名单条目',
      );
      expect(
        entry.value.trim(),
        isNotEmpty,
        reason: '白名单条目 ${entry.key} 必须写明放行原因',
      );
    }
  });

  test('generated supportedLocales matches ARB @@locale', () {
    final generated = File(_generatedLocalizationsPath);
    if (!generated.existsSync()) {
      markTestSkipped('需要先执行 flutter gen-l10n 生成 $generated');
      return;
    }
    final source = generated.readAsStringSync();
    final start = source.indexOf('supportedLocales = <Locale>[');
    expect(start, isNot(-1), reason: '生成文件里找不到 supportedLocales');
    final end = source.indexOf('];', start);
    expect(end, isNot(-1), reason: '生成文件里 supportedLocales 没有闭合');
    final block = source.substring(start, end);
    final generatedLocales = RegExp(r"Locale\('([^']+)'\)")
        .allMatches(block)
        .map((Match match) => match.group(1)!)
        .toSet();

    final arbLocales = <String>{};
    for (final path in <String>[_arbZhPath, _arbEnPath]) {
      final arb = jsonDecode(File(path).readAsStringSync())
          as Map<String, dynamic>;
      final locale = arb['@@locale'];
      if (locale is String) {
        arbLocales.add(locale);
      }
    }

    expect(generatedLocales, arbLocales);
  });
}
