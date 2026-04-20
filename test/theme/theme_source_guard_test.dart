import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-theme library files avoid direct visual literals', () {
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => _isGuardedLibraryFile(file.path))
            .toList()
          ..sort((left, right) => left.path.compareTo(right.path));

    final directColor = RegExp(r'(?:const\s+)?\bColor\(');
    final directFontSize = RegExp(r'fontSize:\s*\d');
    final directInsets = RegExp(
      r'EdgeInsets\.(?:all|only|symmetric|fromLTRB)\([^)]*(?:[:(,]\s*[1-9]\d*(?:\.\d+)?)',
    );
    final directRadius = RegExp(r'(?:BorderRadius|Radius)\.circular\(\d');
    final directTextTheme = RegExp(r'(?:^|[^\w])textTheme(?:\b|\.)');

    final violations = <String>[];
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final (name, pattern) in <(String, RegExp)>[
        ('Color()', directColor),
        ('fontSize', directFontSize),
        ('EdgeInsets literal', directInsets),
        ('circular radius literal', directRadius),
        ('textTheme access', directTextTheme),
      ]) {
        final match = pattern.firstMatch(source);
        if (match != null) {
          violations.add('${file.path}: disallowed $name literal');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

bool _isGuardedLibraryFile(String path) {
  final normalizedPath = path.replaceAll('\\', '/');
  return normalizedPath.endsWith('.dart') &&
      !normalizedPath.startsWith('lib/theme/') &&
      normalizedPath != 'lib/theme.dart';
}
