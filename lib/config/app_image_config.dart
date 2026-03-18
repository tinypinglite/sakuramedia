class AppImageConfig {
  static bool enableBlur = false;
  static double blurSigma = 30;

  @Deprecated('Use enableBlur instead.')
  static bool get enableMask => enableBlur;

  @Deprecated('Use enableBlur instead.')
  static set enableMask(bool value) => enableBlur = value;
}
