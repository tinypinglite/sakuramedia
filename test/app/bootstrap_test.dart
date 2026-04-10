import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/bootstrap.dart';
import 'package:sakuramedia/config/app_image_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bootstrap configures global image cache budget', () {
    final imageCache = PaintingBinding.instance.imageCache;
    final previousMaximumSize = imageCache.maximumSize;
    final previousMaximumSizeBytes = imageCache.maximumSizeBytes;
    final previousPlatformOverride = debugDefaultTargetPlatformOverride;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = previousPlatformOverride;
      imageCache.maximumSize = previousMaximumSize;
      imageCache.maximumSizeBytes = previousMaximumSizeBytes;
    });

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    imageCache.maximumSize = 7;
    imageCache.maximumSizeBytes = 123;

    configureImageCacheBudget();

    expect(imageCache.maximumSize, AppImageConfig.imageCacheMaximumSize);
    expect(
      imageCache.maximumSizeBytes,
      AppImageConfig.imageCacheMaximumSizeBytes,
    );
  });
}
