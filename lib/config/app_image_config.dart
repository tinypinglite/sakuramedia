class AppImageConfig {
  static const int imageCacheMaximumSize = 400;
  static const int imageCacheMaximumSizeBytes = 128 * 1024 * 1024;

  // 通过 `flutter run --dart-define-from-file=.env` 覆盖,`.env` 已 gitignore。
  static bool enableBlur = const bool.fromEnvironment(
    'ENABLE_BLUR',
    defaultValue: false,
  );
  static double blurSigma = 100;
}
