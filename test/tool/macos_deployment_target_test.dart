import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS deployment target stays aligned with plugin requirements', () {
    final podfile = File('macos/Podfile').readAsStringSync();
    final projectFile =
        File('macos/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    expect(podfile, contains("platform :osx, '12.0'"));
    expect(
      RegExp(
        r'MACOSX_DEPLOYMENT_TARGET = 12\.0;',
      ).allMatches(projectFile).length,
      3,
    );
  });
}
