class AppImageConfig {
  static const int imageCacheMaximumSize = 400;
  static const int imageCacheMaximumSizeBytes = 64 * 1024 * 1024;

  // 通过 `flutter run --dart-define-from-file=.env` 覆盖,`.env` 已 gitignore。
  static bool enableBlur = const bool.fromEnvironment(
    'ENABLE_BLUR',
    defaultValue: false,
  );
  static double blurSigma = 100;

  @Deprecated('Use enableBlur instead.')
  static bool get enableMask => enableBlur;

  @Deprecated('Use enableBlur instead.')
  static set enableMask(bool value) => enableBlur = value;
}
