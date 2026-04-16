import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/theme.dart';
import 'dart:io';

void main() {
  testWidgets('theme exposes the default design tokens', (
    WidgetTester tester,
  ) async {
    late AppColors colors;
    late AppComponentTokens componentTokens;
    late AppFormTokens formTokens;
    late AppLayoutTokens layoutTokens;
    late AppNavigationTokens navigationTokens;
    late AppOverlayTokens overlayTokens;
    late AppSpacing spacing;
    late AppRadius radius;
    late AppSidebarTokens sidebarTokens;
    late AppShadows shadows;

    await tester.pumpWidget(
      MaterialApp(
        theme: sakuraThemeData,
        home: Builder(
          builder: (context) {
            colors = context.appColors;
            componentTokens = context.appComponentTokens;
            formTokens = context.appFormTokens;
            layoutTokens = context.appLayoutTokens;
            navigationTokens = context.appNavigationTokens;
            overlayTokens = context.appOverlayTokens;
            spacing = context.appSpacing;
            radius = context.appRadius;
            sidebarTokens = context.appSidebarTokens;
            shadows = context.appShadows;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(colors.surfacePage, const Color(0xFFF5F5F5));
    expect(colors.textOnMedia, const Color(0xFFFFFFFF));
    expect(colors.mediaOverlaySoft, const Color(0x14000000));
    expect(colors.movieCardSubscribedBadgeBackground, const Color(0xFFF97316));
    expect(colors.subscriptionHeartIcon, const Color(0xFFD44B5C));
    expect(colors.movieCardPlayableBadgeBackground, const Color(0xFF1677FF));
    expect(colors.movieDetailPlayableBadgeBackground, const Color(0xFF1677FF));
    expect(colors.movieDetailHeroBackgroundStart, const Color(0xFF000000));
    expect(colors.movieDetailHeroBackgroundEnd, const Color(0xFF000000));
    expect(colors.movieDetailHeatIcon, const Color(0xFFD84C57));
    expect(colors.desktopSidebarGlassTint, const Color(0x4CEFEFEF));
    expect(colors.desktopSidebarGlassHover, const Color(0x80FFFFFF));
    expect(colors.desktopSidebarGlassActive, const Color(0x99FFFFFF));
    expect(colors.selectionSurface, const Color(0xFFEAF3FF));
    expect(colors.infoForeground, const Color(0xFF175CD3));
    expect(colors.warningForeground, const Color(0xFFB54708));
    expect(colors.errorAccentForeground, const Color(0xFFF04438));
    expect(colors.successForeground, const Color(0xFF027A48));
    expect(spacing.xl, 24);
    expect(radius.lg, 16);
    expect(componentTokens.overviewStatTileMinWidth, 150);
    expect(componentTokens.desktopTitleBarHeight, 56);
    expect(componentTokens.desktopMacTrafficLightInsetWidth, 52);
    expect(componentTokens.desktopTitleBarControlGap, 8);
    expect(componentTokens.movieCardTargetWidth, 160);
    expect(componentTokens.movieThumbnailTargetWidth, 128);
    expect(componentTokens.movieCardAspectRatio, 0.7);
    expect(componentTokens.movieCardCoverVisibleWidthFactor, 0.47);
    expect(componentTokens.iconSizeXs, 16);
    expect(componentTokens.iconSizeSm, 18);
    expect(componentTokens.iconSizeMd, 20);
    expect(componentTokens.iconSizeLg, 22);
    expect(componentTokens.iconSizeXl, 24);
    expect(componentTokens.iconSize2xl, 32);
    expect(componentTokens.iconSize3xl, 36);
    expect(componentTokens.iconSize4xl, 44);
    expect(componentTokens.movieCardStatusBadgeSize, 24);
    expect(componentTokens.movieDetailSectionGap, 4);
    expect(componentTokens.movieDetailSectionTitleGap, 8);
    expect(componentTokens.movieDetailPillHorizontalPadding, 6);
    expect(componentTokens.movieDetailPillVerticalPadding, 3);
    expect(componentTokens.movieDetailPillGap, 6);
    expect(componentTokens.movieDetailBottomBarMinHeight, 42);
    expect(componentTokens.playlistBannerHeight, 100);
    expect(componentTokens.playlistDialogWidth, 520);
    expect(componentTokens.mobileBottomNavHeight, 52);
    expect(componentTokens.mobileTopTabHeight, 48);
    expect(componentTokens.mobileSubpageLeadingWidth, 40);
    expect(componentTokens.mobileLatestMovieCardWidth, 142);
    expect(componentTokens.mobileFollowMovieCardHeight, 150);
    expect(componentTokens.mobileFollowMovieThinCoverWidth, 96);
    expect(componentTokens.mobileFollowMovieStillWidth, 86);
    expect(formTokens.labelGap, 8);
    expect(formTokens.compactFieldHeight, 36);
    expect(formTokens.menuItemHeight, 40);
    expect(formTokens.menuMaxHeight, 240);
    expect(layoutTokens.dialogWidthSm, 420);
    expect(layoutTokens.dialogWidthMd, 520);
    expect(layoutTokens.emptySectionVerticalPadding, 48);
    expect(navigationTokens.desktopTabHeight, 40);
    expect(navigationTokens.compactTabHeight, 32);
    expect(navigationTokens.mobileIndicatorThickness, 5);
    expect(overlayTokens.menuWidthSm, 144);
    expect(overlayTokens.menuWidthMd, 188);
    expect(overlayTokens.playerDrawerWidth, 196);
    expect(overlayTokens.playerInfoDrawerWidth, 360);
    expect(overlayTokens.controlLabelFontSize, 14);
    expect(overlayTokens.playerSeekBarBottomInset, 75);
    expect(
      componentTokens.moviePlayerThumbnailAspectRatio,
      closeTo(16 / 9, 0.0001),
    );
    expect(sidebarTokens.expandedWidth, 220);
    expect(sidebarTokens.collapsedWidth, 72);
    expect(sidebarTokens.itemHeight, 44);
    expect(AppPageInsets.desktopStandard.left, 24);
    expect(AppPageInsets.compactStandard.left, 8);
    expect(shadows.card, isNotEmpty);
  });

  test('component token source only exposes global icon size scale', () {
    final source =
        File('lib/theme/app_component_tokens.dart').readAsStringSync();

    expect(source, contains('iconSizeXs'));
    expect(source, contains('iconSizeSm'));
    expect(source, contains('iconSizeMd'));
    expect(source, contains('iconSizeLg'));
    expect(source, contains('iconSizeXl'));
    expect(source, contains('iconSize2xl'));
    expect(source, contains('iconSize3xl'));
    expect(source, contains('iconSize4xl'));
    expect(source, isNot(contains('movieCardPlaceholderIconSize')));
    expect(source, isNot(contains('movieCardErrorIconSize')));
    expect(source, isNot(contains('movieCardStatusIconSize')));
    expect(source, isNot(contains('movieDetailMetaRowIconSize')));
  });
}
