import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('glass package imports stay inside the glass implementation layer', () {
    final violations = <String>[];

    for (final file in _dartFiles()) {
      final path = _normalize(file.path);
      final source = file.readAsStringSync();

      if (path.startsWith('lib/widgets/base/layout/glass/')) {
        continue;
      }

      for (final match in _importMatches(source, 'liquid_glass_widgets')) {
        violations.add(
          '$path:${match.line} imports package:liquid_glass_widgets',
        );
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('public pages and shells do not import the glass implementation', () {
    final violations = <String>[];

    for (final file in _dartFiles()) {
      final path = _normalize(file.path);
      if (path.startsWith('lib/widgets/base/')) {
        continue;
      }

      final source = file.readAsStringSync();
      for (final match in _importMatches(
        source,
        'widgets/base/layout/glass/',
      )) {
        violations.add(
          '$path:${match.line} imports the internal glass implementation',
        );
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('tests use the public surface runtime instead of the glass package', () {
    final violations = <String>[];

    for (final file in _testFiles()) {
      final path = _normalize(file.path);
      final source = file.readAsStringSync();

      for (final match in _importMatches(source, 'liquid_glass_widgets')) {
        violations.add(
          '$path:${match.line} imports package:liquid_glass_widgets',
        );
      }
      for (final match in _importMatches(
        source,
        'widgets/base/layout/glass/',
      )) {
        violations.add(
          '$path:${match.line} imports the internal glass implementation',
        );
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('flat glass implementation stays package-free and blur-free', () {
    const paths = <String>[
      'lib/widgets/base/layout/glass/app_glass_flat_backend.dart',
      'lib/widgets/base/layout/glass/app_glass_flat_surface.dart',
      'lib/widgets/base/layout/glass/app_glass_flat_style.dart',
    ];
    final violations = <String>[];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      if (source.contains('liquid_glass_widgets')) {
        violations.add('$path references liquid_glass_widgets');
      }
      if (source.contains('BackdropFilter')) {
        violations.add('$path references BackdropFilter');
      }
      if (source.contains('ImageFilter.blur')) {
        violations.add('$path references ImageFilter.blur');
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

Iterable<File> _dartFiles() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}

Iterable<File> _testFiles() {
  return Directory('test')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}

Iterable<({int line, String text})> _importMatches(
  String source,
  String needle,
) sync* {
  final lines = source.split('\n');
  for (var index = 0; index < lines.length; index++) {
    final line = lines[index].trim();
    if ((line.startsWith('import ') || line.startsWith('export ')) &&
        line.contains(needle)) {
      yield (line: index + 1, text: line);
    }
  }
}

String _normalize(String path) => path.replaceAll(r'\', '/');
