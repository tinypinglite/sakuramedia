import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS and Android enable Impeller while macOS uses the compatible renderer', () {
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
    expect(
      iosInfoPlist,
      matches(RegExp(r'<key>FLTEnableImpeller</key>\s*<true/>')),
    );
    expect(
      macosInfoPlist,
      matches(RegExp(r'<key>FLTEnableImpeller</key>\s*<false/>')),
    );
  });
}
