import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS declares local network access for LAN backend connections', () {
    final infoPlist = File('macos/Runner/Info.plist').readAsStringSync();
    final entitlements = File(
      'macos/Runner/Release.entitlements',
    ).readAsStringSync();

    expect(
      infoPlist,
      matches(
        RegExp(
          r'<key>NSLocalNetworkUsageDescription</key>\s*<string>[^<]+</string>',
        ),
      ),
    );
    expect(
      entitlements,
      matches(
        RegExp(r'<key>com\.apple\.security\.network\.client</key>\s*<true/>'),
      ),
    );
  });
}
