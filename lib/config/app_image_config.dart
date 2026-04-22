class AppImageConfig {
  static const int imageCacheMaximumSize = 400;
  static const int imageCacheMaximumSizeBytes = 64 * 1024 * 1024;

  static bool enableBlur = true;
  static double blurSigma = 30;

  @Deprecated('Use enableBlur instead.')
  static bool get enableMask => enableBlur;

  @Deprecated('Use enableBlur instead.')
  static set enableMask(bool value) => enableBlur = value;
}
