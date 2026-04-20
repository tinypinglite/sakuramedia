import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:sakuramedia/theme.dart';

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
    late AppTextScale textScale;
    late AppTextWeights textWeights;
    late AppTextPalette textPalette;

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
            textScale = context.appTextScale;
            textWeights = context.appTextWeights;
            textPalette = context.appTextPalette;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(colors.surfacePage, const Color(0xFFF5F5F5));
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
    expect(colors.errorAccentForeground, const Color(0xFFF04438));
    expect(textScale.s20, 20);
    expect(textScale.s18, 18);
    expect(textScale.s16, 16);
    expect(textScale.s14, 14);
    expect(textScale.s12, 12);
    expect(textScale.s10, 10);
    expect(textWeights.regular, FontWeight.w400);
    expect(textWeights.medium, FontWeight.w500);
    expect(textWeights.semibold, FontWeight.w600);
    expect(textPalette.primary, const Color(0xFF1F1A18));
    expect(textPalette.secondary, const Color(0xFF342D2A));
    expect(textPalette.tertiary, const Color(0xFF4D4440));
    expect(textPalette.muted, const Color(0xFF6B625E));
    expect(textPalette.accent, const Color(0xFF6B2D2A));
    expect(textPalette.onMedia, const Color(0xFFFFFFFF));
    expect(textPalette.info, const Color(0xFF175CD3));
    expect(textPalette.warning, const Color(0xFFB54708));
    expect(textPalette.error, const Color(0xFFB42318));
    expect(textPalette.success, const Color(0xFF027A48));
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
    expect(componentTokens.iconSize2xs, 14);
    expect(componentTokens.iconSize3xs, 12);
    expect(componentTokens.iconSizeSm, 18);
    expect(componentTokens.iconSizeMd, 20);
    expect(componentTokens.iconSizeLg, 22);
    expect(componentTokens.iconSizeXl, 24);
    expect(componentTokens.iconSize2xl, 32);
    expect(componentTokens.iconSize3xl, 36);
    expect(componentTokens.iconSize4xl, 44);
    expect(componentTokens.buttonHeightMd, 36);
    expect(componentTokens.buttonHeight2xs, 24);
    expect(componentTokens.buttonHeight3xs, 20);
    expect(componentTokens.buttonHorizontalPaddingSm, 10);
    expect(componentTokens.buttonHorizontalPadding2xs, 6);
    expect(componentTokens.buttonHorizontalPadding3xs, 4);
    expect(componentTokens.buttonGapXs, 4);
    expect(componentTokens.buttonGap2xs, 4);
    expect(componentTokens.buttonGap3xs, 2);
    expect(componentTokens.movieCardStatusBadgeSize, 24);
    expect(componentTokens.movieDetailSectionGap, 16);
    expect(componentTokens.movieDetailSectionTitleGap, 8);
    expect(componentTokens.movieDetailPillHorizontalPadding, 5);
    expect(componentTokens.movieDetailPillVerticalPadding, 2);
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
    expect(formTokens.miniFieldHorizontalPadding, 10);
    expect(formTokens.miniFieldHeight, 28);
    expect(formTokens.miniMenuItemHeight, 34);
    expect(formTokens.compactFieldHeight, 36);
    expect(formTokens.menuItemHeight, 40);
    expect(formTokens.menuMaxHeight, 240);
    expect(layoutTokens.dialogWidthSm, 420);
    expect(layoutTokens.dialogWidthMd, 520);
    expect(layoutTokens.emptySectionVerticalPadding, 48);
    expect(navigationTokens.desktopTabHeight, 40);
    expect(navigationTokens.compactTabHeight, 32);
    expect(navigationTokens.mobileTopTabHeight, 52);
    expect(navigationTokens.mobileIndicatorThickness, 5);
    expect(overlayTokens.menuWidthSm, 144);
    expect(overlayTokens.menuWidthMd, 188);
    expect(overlayTokens.playerDrawerWidth, 196);
    expect(overlayTokens.playerInfoDrawerWidth, 360);
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

  test('mobile theme exposes the mobile typography and size mappings', () {
    expect(sakuraMobileThemeData.appTextScale.s20, 20);
    expect(sakuraMobileThemeData.appTextScale.s18, 18);
    expect(sakuraMobileThemeData.appTextWeights.semibold, FontWeight.w600);
    expect(sakuraMobileThemeData.appTextScale.s16, 16);
    expect(sakuraMobileThemeData.appTextScale.s14, 14);
    expect(sakuraMobileThemeData.appTextScale.s12, 12);
    expect(sakuraMobileThemeData.appTextScale.s10, 10);
    expect(
      sakuraMobileThemeData.textTheme.titleSmall?.fontSize,
      sakuraMobileThemeData.appTextScale.s16,
    );
    expect(
      sakuraMobileThemeData.textTheme.bodyMedium?.fontSize,
      sakuraMobileThemeData.appTextScale.s14,
    );
    expect(
      sakuraMobileThemeData.textTheme.labelMedium?.fontSize,
      sakuraMobileThemeData.appTextScale.s12,
    );
    expect(
      sakuraMobileThemeData.textTheme.labelSmall?.fontSize,
      sakuraMobileThemeData.appTextScale.s10,
    );
    expect(sakuraMobileThemeData.appNavigationTokens.mobileTopTabHeight, 36);
    expect(sakuraMobileThemeData.appFormTokens.compactFieldHeight, 40);
    expect(sakuraMobileThemeData.appFormTokens.miniMenuItemHeight, 38);
    expect(sakuraMobileThemeData.appComponentTokens.buttonHeightMd, 40);
    expect(sakuraMobileThemeData.appComponentTokens.buttonHeightSm, 36);
    expect(sakuraMobileThemeData.appComponentTokens.buttonHeight2xs, 28);
    expect(sakuraMobileThemeData.appComponentTokens.buttonHeight3xs, 24);
    expect(
      sakuraMobileThemeData.appComponentTokens.movieDetailBottomBarMinHeight,
      48,
    );
    expect(sakuraMobileThemeData.appComponentTokens.mobileBottomNavHeight, 56);
    expect(
      sakuraMobileThemeData.appComponentTokens.mobileFollowMovieCardHeight,
      158,
    );
  });

  test('component token source only exposes global icon size scale', () {
    final source =
        File('lib/theme/app_component_tokens.dart').readAsStringSync();

    expect(source, contains('iconSizeXs'));
    expect(source, contains('iconSize2xs'));
    expect(source, contains('iconSize3xs'));
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
