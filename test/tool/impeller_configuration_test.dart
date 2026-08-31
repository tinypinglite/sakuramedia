import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('supported native platforms enable Impeller by default', () {
    final androidManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final iosInfoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final macosInfoPlist = File('macos/Runner/Info.plist').readAsStringSync();

    expect(
      androidManifest,
      matches(
        RegExp(
          r'android:name="io\.flutter\.embedding\.android\.EnableImpeller"\s+'
          r'android:value="true"',
        ),
      ),
    );
    for (final plist in [iosInfoPlist, macosInfoPlist]) {
      expect(plist, matches(RegExp(r'<key>FLTEnableImpeller</key>\s*<true/>')));
    }
  });
}
