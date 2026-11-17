import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 一套主题色的品牌锚点（明/暗各一组）。
///
/// 中性面、边框、文字和状态色由 [AppColors] / [AppTextPalette] 的明暗规格
/// 统一提供；这里只定义随主题色变化的槽位。新增主题色 = 增加一个
/// [AppThemeColor] 常量并加入 [AppThemeColor.values]。
@immutable
class AppThemeColor {
  const AppThemeColor({
    required this.id,
    required this.light,
    required this.dark,
  });

  final String id;
  final AppBrandColors light;
  final AppBrandColors dark;

  /// 主题色显示名；按当前语言渲染。
  ///
  /// 主题色是封闭集合（见 [values]），正常不会命中兜底分支；万一命中，
  /// 回退的是机器标识 [id]（英文），不是硬编码中文。
  String labelFor(AppLocalizations l10n) => switch (id) {
    burgundyId => l10n.themeColorBurgundyLabel,
    crimsonId => l10n.themeColorCrimsonLabel,
    kleinBlueId => l10n.themeColorKleinBlueLabel,
    silhouetteId => l10n.themeColorSilhouetteLabel,
    _ => id,
  };

  static const String burgundyId = 'burgundy';

  static const AppThemeColor burgundy = AppThemeColor(
    id: burgundyId,
    light: AppBrandColors(
      primary: Color(0xFF6B2D2A),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE8D8D3),
      onPrimaryContainer: Color(0xFF2F1412),
      secondary: Color(0xFF8B5E57),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFF2E6E1),
      onSecondaryContainer: Color(0xFF2B201E),
      tertiary: Color(0xFF6C584C),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFE8DDD6),
      onTertiaryContainer: Color(0xFF251C17),
      surfaceTint: Color(0xFF6B2D2A),
      inversePrimary: Color(0xFFFFB4A9),
      selectionSurface: Color(0xFFF7ECEB),
      selectionBorder: Color(0xFF6B2D2A),
      selectedPlotBorder: Color(0xFF6B2D2A),
      accent: Color(0xFF6B2D2A),
    ),
    dark: AppBrandColors(
      primary: Color(0xFFE9A29B),
      onPrimary: Color(0xFF4A1310),
      primaryContainer: Color(0xFF5C2A26),
      onPrimaryContainer: Color(0xFFFFDAD5),
      secondary: Color(0xFFE5BBB3),
      onSecondary: Color(0xFF442925),
      secondaryContainer: Color(0xFF5D3A35),
      onSecondaryContainer: Color(0xFFFFDCD5),
      tertiary: Color(0xFFD8C2B6),
      onTertiary: Color(0xFF3B2A22),
      tertiaryContainer: Color(0xFF52443B),
      onTertiaryContainer: Color(0xFFF5DFD3),
      surfaceTint: Color(0xFFE9A29B),
      inversePrimary: Color(0xFFA6534D),
      selectionSurface: Color(0xFF3A2422),
      selectionBorder: Color(0xFFE9A29B),
      selectedPlotBorder: Color(0xFFE9A29B),
      accent: Color(0xFFE9A29B),
    ),
  );

  static const String crimsonId = 'crimson';

  /// 绛红：网易云经典红相沉一档，饱和但不刺眼。
  static const AppThemeColor crimson = AppThemeColor(
    id: crimsonId,
    light: AppBrandColors(
      primary: Color(0xFFA8201F),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFFFD7D1),
      onPrimaryContainer: Color(0xFF3E0F0B),
      secondary: Color(0xFF99564E),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFFADFDB),
      onSecondaryContainer: Color(0xFF401B16),
      tertiary: Color(0xFF6B594E),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFEBE1DA),
      onTertiaryContainer: Color(0xFF2B221C),
      surfaceTint: Color(0xFFA8201F),
      inversePrimary: Color(0xFFFBB7AE),
      selectionSurface: Color(0xFFFEECEA),
      selectionBorder: Color(0xFFA8201F),
      selectedPlotBorder: Color(0xFFA8201F),
      accent: Color(0xFFA8201F),
    ),
    dark: AppBrandColors(
      primary: Color(0xFFDD766A),
      onPrimary: Color(0xFF420E0B),
      primaryContainer: Color(0xFF612722),
      onPrimaryContainer: Color(0xFFFFDAD4),
      secondary: Color(0xFFE7B9B2),
      onSecondary: Color(0xFF411814),
      secondaryContainer: Color(0xFF683832),
      onSecondaryContainer: Color(0xFFFDDAD4),
      tertiary: Color(0xFFD4C6BD),
      onTertiary: Color(0xFF2C231D),
      tertiaryContainer: Color(0xFF62554D),
      onTertiaryContainer: Color(0xFFEBE1DA),
      surfaceTint: Color(0xFFDD766A),
      inversePrimary: Color(0xFF83433B),
      selectionSurface: Color(0xFF371D1A),
      selectionBorder: Color(0xFFDD766A),
      selectedPlotBorder: Color(0xFFDD766A),
      accent: Color(0xFFDD766A),
    ),
  );

  static const String kleinBlueId = 'klein-blue';

  /// 克莱因蓝：国际克莱因蓝相，偏艺术感的深蓝。
  static const AppThemeColor kleinBlue = AppThemeColor(
    id: kleinBlueId,
    light: AppBrandColors(
      primary: Color(0xFF1F42A5),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFD3E3FF),
      onPrimaryContainer: Color(0xFF0F1F46),
      secondary: Color(0xFF586B95),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFDEE6F8),
      onSecondaryContainer: Color(0xFF1D273E),
      tertiary: Color(0xFF675B54),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFEAE1DC),
      onTertiaryContainer: Color(0xFF2A221E),
      surfaceTint: Color(0xFF1F42A5),
      inversePrimary: Color(0xFFB3CAFC),
      selectionSurface: Color(0xFFE9F1FF),
      selectionBorder: Color(0xFF1F42A5),
      selectedPlotBorder: Color(0xFF1F42A5),
      accent: Color(0xFF1F42A5),
    ),
    dark: AppBrandColors(
      primary: Color(0xFF83A3EA),
      onPrimary: Color(0xFF0D1F4C),
      primaryContainer: Color(0xFF263A67),
      onPrimaryContainer: Color(0xFFD6E5FF),
      secondary: Color(0xFFB6C6E7),
      onSecondary: Color(0xFF1A263F),
      secondaryContainer: Color(0xFF394766),
      onSecondaryContainer: Color(0xFFD9E3F8),
      tertiary: Color(0xFFD1C6C0),
      onTertiary: Color(0xFF2D231D),
      tertiaryContainer: Color(0xFF62554E),
      onTertiaryContainer: Color(0xFFEAE1DC),
      surfaceTint: Color(0xFF83A3EA),
      inversePrimary: Color(0xFF425785),
      selectionSurface: Color(0xFF1B253B),
      selectionBorder: Color(0xFF83A3EA),
      selectedPlotBorder: Color(0xFF83A3EA),
      accent: Color(0xFF83A3EA),
    ),
  );

  static const String silhouetteId = 'silhouette';

  /// 映辉：冷调深暖灰，低饱和中性主题。
  static const AppThemeColor silhouette = AppThemeColor(
    id: silhouetteId,
    light: AppBrandColors(
      primary: Color(0xFF3E322F),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFE6E2E0),
      onPrimaryContainer: Color(0xFF2A1E1B),
      secondary: Color(0xFF736966),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFEBE5E3),
      onSecondaryContainer: Color(0xFF2C2624),
      tertiary: Color(0xFF555E6A),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFDDE4EC),
      onTertiaryContainer: Color(0xFF1E252D),
      surfaceTint: Color(0xFF3E322F),
      inversePrimary: Color(0xFFD3C8C4),
      selectionSurface: Color(0xFFF3F0EF),
      selectionBorder: Color(0xFF3E322F),
      selectedPlotBorder: Color(0xFF3E322F),
      accent: Color(0xFF3E322F),
    ),
    dark: AppBrandColors(
      primary: Color(0xFFC9BAB5),
      onPrimary: Color(0xFF2C201C),
      primaryContainer: Color(0xFF463834),
      onPrimaryContainer: Color(0xFFE8E3E2),
      secondary: Color(0xFFCDC3C0),
      onSecondary: Color(0xFF2C2522),
      secondaryContainer: Color(0xFF4E4643),
      onSecondaryContainer: Color(0xFFE9E1DE),
      tertiary: Color(0xFFC0CAD6),
      onTertiary: Color(0xFF1F262F),
      tertiaryContainer: Color(0xFF505964),
      onTertiaryContainer: Color(0xFFDDE4EC),
      surfaceTint: Color(0xFFC9BAB5),
      inversePrimary: Color(0xFF605552),
      selectionSurface: Color(0xFF2B2321),
      selectionBorder: Color(0xFFC9BAB5),
      selectedPlotBorder: Color(0xFFC9BAB5),
      accent: Color(0xFFC9BAB5),
    ),
  );

  static const List<AppThemeColor> values = <AppThemeColor>[
    crimson,
    burgundy,
    kleinBlue,
    silhouette,
  ];

  static AppThemeColor fromId(String? id) {
    for (final color in values) {
      if (color.id == id) {
        return color;
      }
    }
    return crimson;
  }

  AppBrandColors forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }
}

/// 主题色在某一明暗模式下的全部品牌槽位。
@immutable
class AppBrandColors {
  const AppBrandColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.surfaceTint,
    required this.inversePrimary,
    required this.selectionSurface,
    required this.selectionBorder,
    required this.selectedPlotBorder,
    required this.accent,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color surfaceTint;
  final Color inversePrimary;
  final Color selectionSurface;
  final Color selectionBorder;
  final Color selectedPlotBorder;
  final Color accent;
}
