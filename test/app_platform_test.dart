import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/app_platform.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Linux resolves to the desktop platform', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    expect(resolveAppPlatform(), AppPlatform.desktop);
  });
}
