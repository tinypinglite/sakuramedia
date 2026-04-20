import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS deployment target stays aligned with plugin requirements', () {
    final podfile = File('macos/Podfile').readAsStringSync();
    final projectFile =
        File('macos/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    expect(podfile, contains("platform :osx, '10.15'"));
    expect(
      RegExp(
        r'MACOSX_DEPLOYMENT_TARGET = 10\.15;',
      ).allMatches(projectFile).length,
      3,
    );
  });
}
