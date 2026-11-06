import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_pill.dart';

/// 状态徽章的跨业务语义。
enum AppStatusSemantic {
  neutral,
  inProgress,
  queued,
  success,
  warning,
  error,
  muted;

  /// 把后端/业务状态字符串归一为共享语义；未知值回落到 [neutral]。
  static AppStatusSemantic fromWire(String? status) {
    final normalized = status?.trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
    return switch (normalized) {
      'in_progress' || 'inprogress' => AppStatusSemantic.inProgress,
      'queued' || 'pending' => AppStatusSemantic.queued,
      'success' || 'succeeded' => AppStatusSemantic.success,
      'warning' || 'partial' => AppStatusSemantic.warning,
      'error' || 'failed' => AppStatusSemantic.error,
      'blocked' => AppStatusSemantic.muted,
      _ => AppStatusSemantic.neutral,
    };
  }
}

/// 已解析好的状态徽章语义。各业务方维护自己的状态枚举 →
/// [AppStatusChipPalette] 映射，只共享 [AppStatusChip] 的渲染逻辑。
///
/// 常见 4 态 + muted 一律走命名工厂 [neutral]/[success]/[warning]/[error]/[muted]，
/// 不要在业务侧再写第 N 份 `_xxxPalette(context)` helper。图标可覆盖，
/// 未指定则用各态标准图标（notTested/probing 都走 [neutral]，图标传 hourglass 即可）。
@immutable
class AppStatusChipPalette {
  const AppStatusChipPalette({required this.tone, required this.icon});

  /// 中性态（未测/待检测/probing）——`surfaceMuted` + `borderSubtle` + secondary 文本。
  /// probing 场景传 `icon: Icons.hourglass_top`。
  factory AppStatusChipPalette.neutral({
    IconData icon = Icons.radio_button_unchecked,
  }) {
    return AppStatusChipPalette(tone: AppPillTone.neutral, icon: icon);
  }

  /// 品牌强调态——`selectionSurface` + accent 文本。
  factory AppStatusChipPalette.primary({
    IconData icon = Icons.radio_button_checked,
  }) {
    return AppStatusChipPalette(tone: AppPillTone.primary, icon: icon);
  }

  /// 进行中/信息态——`infoSurface` + info tone。
  factory AppStatusChipPalette.info({IconData icon = Icons.info_outline}) {
    return AppStatusChipPalette(tone: AppPillTone.info, icon: icon);
  }

  /// 成功态——`successSurface` + success tone。
  factory AppStatusChipPalette.success({
    IconData icon = Icons.check_circle_outline,
  }) {
    return AppStatusChipPalette(tone: AppPillTone.success, icon: icon);
  }

  /// 警告态——`warningSurface` + warning tone。
  factory AppStatusChipPalette.warning({
    IconData icon = Icons.warning_amber_rounded,
  }) {
    return AppStatusChipPalette(tone: AppPillTone.warning, icon: icon);
  }

  /// 错误态——`errorSurface` + error tone。
  factory AppStatusChipPalette.error({IconData icon = Icons.error_outline}) {
    return AppStatusChipPalette(tone: AppPillTone.error, icon: icon);
  }

  /// 灰态（禁用/blocked）——与 [neutral] 同底色但 muted 文本。
  factory AppStatusChipPalette.muted({IconData icon = Icons.block}) {
    return AppStatusChipPalette(tone: AppPillTone.muted, icon: icon);
  }

  /// 按跨业务语义取标准调色板；[icon] 可覆盖该语义的默认图标。
  factory AppStatusChipPalette.forSemantic(
    AppStatusSemantic semantic, {
    IconData? icon,
  }) {
    return switch (semantic) {
      AppStatusSemantic.neutral => AppStatusChipPalette.neutral(
        icon: icon ?? Icons.radio_button_unchecked,
      ),
      AppStatusSemantic.inProgress => AppStatusChipPalette.info(
        icon: icon ?? Icons.autorenew,
      ),
      AppStatusSemantic.queued => AppStatusChipPalette.neutral(
        icon: icon ?? Icons.schedule,
      ),
      AppStatusSemantic.success => AppStatusChipPalette.success(
        icon: icon ?? Icons.check_circle_outline,
      ),
      AppStatusSemantic.warning => AppStatusChipPalette.warning(
        icon: icon ?? Icons.warning_amber_rounded,
      ),
      AppStatusSemantic.error => AppStatusChipPalette.error(
        icon: icon ?? Icons.error_outline,
      ),
      AppStatusSemantic.muted => AppStatusChipPalette.muted(
        icon: icon ?? Icons.block,
      ),
    };
  }

  final AppPillTone tone;
  final IconData icon;
}

/// 状态徽章的纯展示层：`[图标或 spinner] 标签 (可选 detail)`，胶囊底色。
///
/// 不含交互逻辑（点击/tooltip 由调用方按需包一层）；调用方只需提供已解析好的
/// [AppStatusChipPalette]。容器和调色板由 [AppPill] 统一承载。
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    required this.palette,
    this.isBusy = false,
    this.detail,
    this.dense = false,
  });

  final String label;
  final AppStatusChipPalette palette;

  /// true 时用 spinner 替代 [AppStatusChipPalette.icon]（例如"检测中"态）。
  final bool isBusy;
  final String? detail;

  /// dense=true 用在需要更紧凑的横条/阵列场景（矮一点、字更小）。
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = resolveAppPillColors(context, palette.tone);
    final iconSize = dense
        ? context.appComponentTokens.iconSize3xs
        : context.appComponentTokens.iconSize2xs;
    final textSize = dense ? AppTextSize.s10 : AppTextSize.s12;

    return AppPill(
      label: label,
      tone: palette.tone,
      size: dense ? AppPillSize.compact : AppPillSize.prominent,
      emphasis: AppPillEmphasis.medium,
      leading: isBusy
          ? SizedBox(
              width: iconSize,
              height: iconSize,
              child: CircularProgressIndicator.adaptive(
                backgroundColor: switch (Theme.of(context).platform) {
                  TargetPlatform.iOS ||
                  TargetPlatform.macOS => colors.foreground,
                  _ => null,
                },
                strokeWidth: 1.6,
                valueColor: AlwaysStoppedAnimation<Color?>(colors.foreground),
              ),
            )
          : Icon(palette.icon),
      trailing: detail != null && detail!.isNotEmpty
          ? Text(
              detail!,
              style: resolveAppTextStyle(
                context,
                size: textSize,
                weight: AppTextWeight.regular,
                tone: AppTextTone.primary,
              ).copyWith(color: colors.foreground),
            )
          : null,
    );
  }
}
