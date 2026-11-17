class AppImageConfig {
  static const int imageCacheMaximumSize = 400;
  static const int imageCacheMaximumSizeBytes = 128 * 1024 * 1024;

  // 通过 `flutter run --dart-define-from-file=.env` 覆盖,`.env` 已 gitignore。
  // 开启后图片显示为纯色遮罩块，不发起图片请求（开发时防误展示）。
  static bool enableBlur = const bool.fromEnvironment(
    'ENABLE_BLUR',
    defaultValue: false,
  );
}
