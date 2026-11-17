import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _load(String path) {
  return jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
}

Set<String> _keys(Map<String, dynamic> arb) {
  return arb.keys.where((String key) => !key.startsWith('@')).toSet();
}

Set<String> _placeholders(Object? value) {
  if (value is! String) {
    return <String>{};
  }
  return RegExp(
    r'\{(\w+)\}',
  ).allMatches(value).map((match) => match.group(1)!).toSet();
}

void main() {
  test('zh and en ARB files keep key and placeholder parity', () {
    final zh = _load('lib/l10n/app_zh.arb');
    final en = _load('lib/l10n/app_en.arb');

    expect(_keys(en), _keys(zh));
    for (final key in _keys(zh)) {
      expect(_placeholders(en[key]), _placeholders(zh[key]), reason: key);
    }
  });
}
