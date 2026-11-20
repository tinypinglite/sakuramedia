abstract final class AppTvTokens {
  static const double safeHorizontal = 56;
  static const double safeVertical = 28;
  static const double navHeight = 76;
  static const double navItemMinWidth = 112;
  static const double navItemHeight = 48;
  static const double sectionGap = 34;
  static const double gridGap = 20;
  static const double gridBreakpointWide = 1500;
  static const int gridColumnsWide = 6;
  static const int gridColumnsNarrow = 4;
  static const double sortDialogWidth = 720;
  static const double posterWidth = 176;
  static const double controlHeight = 56;
  static const double actionMinWidth = 148;
  static const double playlistCardWidth = 360;
  static const double plotThumbnailWidth = 338;
  static const double plotThumbnailHeight = 190;
  static const double heroHeight = 420;

  static int gridColumnsForWidth(double width) {
    return width >= gridBreakpointWide ? gridColumnsWide : gridColumnsNarrow;
  }
}
