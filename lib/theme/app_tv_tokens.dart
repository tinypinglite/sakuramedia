abstract final class AppTvTokens {
  static const double safeHorizontal = 56;
  static const double safeVertical = 28;
  static const double navHeight = 76;
  static const double navItemMinWidth = 112;
  static const double navItemHeight = 48;
  static const double contentMaxWidth = 1800;
  static const double sectionGap = 34;
  static const double railGap = 18;
  static const double gridGap = 20;
  static const double gridBreakpointWide = 1500;
  static const int gridColumnsWide = 6;
  static const int gridColumnsNarrow = 4;
  static const double posterWidth = 176;
  static const double posterHeight = 264;
  static const double landscapeCardWidth = 320;
  static const double landscapeCardHeight = 180;
  static const double playlistCardWidth = 360;
  static const double playlistCardHeight = 150;
  static const double plotThumbnailWidth = 338;
  static const double plotThumbnailHeight = 190;
  static const double heroHeight = 420;
  static const double focusScale = 1.045;
  static const double focusBorderWidth = 4;
  static const double focusOverflow = 12;
  static const double actionHeight = 52;
  static const double actionMinWidth = 148;
  static const double progressBarHeight = 4;
  static const Duration focusDuration = Duration(milliseconds: 140);

  static int gridColumnsForWidth(double width) {
    return width >= gridBreakpointWide ? gridColumnsWide : gridColumnsNarrow;
  }
}
