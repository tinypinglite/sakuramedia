import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/media/providers/player_subtitle_preference_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 播放器字幕设置内容；桌面浮层和移动抽屉共用。
class MoviePlayerSubtitleSettingsView extends ConsumerWidget {
  const MoviePlayerSubtitleSettingsView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final preference =
        ref.watch(playerSubtitlePreferenceControllerProvider).value ??
        const PlayerSubtitlePreference();
    final controller = ref.read(
      playerSubtitlePreferenceControllerProvider.notifier,
    );

    return Column(
      key: const Key('movie-player-subtitle-settings'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppIconButton(
              key: const Key('movie-player-subtitle-settings-back'),
              size: AppIconButtonSize.mini,
              tooltip: l10n.commonBack,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Text(
                l10n.moviePlayerSubtitleSettingsTitle,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: spacing.md),
        _SubtitleSettingSlider(
          key: const Key('movie-player-subtitle-settings-scale'),
          sliderKey: const Key('movie-player-subtitle-settings-scale-slider'),
          label:
              '${l10n.moviePlayerSubtitleSizeLabel}  '
              '${preference.scale.toStringAsFixed(2)}x',
          value: preference.scale,
          min: PlayerSubtitlePreference.minScale,
          max: PlayerSubtitlePreference.maxScale,
          divisions: 25,
          onChanged: controller.setScale,
        ),
        SizedBox(height: spacing.md),
        _SubtitleSettingSlider(
          key: const Key('movie-player-subtitle-settings-offset'),
          sliderKey: const Key('movie-player-subtitle-settings-offset-slider'),
          label:
              '${l10n.moviePlayerSubtitlePositionLabel}  '
              '${preference.bottomOffset.round()}',
          value: preference.bottomOffset,
          min: PlayerSubtitlePreference.minBottomOffset,
          max: PlayerSubtitlePreference.maxBottomOffset,
          divisions: 24,
          onChanged: controller.setBottomOffset,
        ),
        SizedBox(height: spacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: AppTextButton(
            key: const Key('movie-player-subtitle-settings-reset'),
            label: l10n.moviePlayerSubtitleSettingsReset,
            size: AppTextButtonSize.small,
            onPressed: controller.reset,
          ),
        ),
      ],
    );
  }
}

class _SubtitleSettingSlider extends StatefulWidget {
  const _SubtitleSettingSlider({
    super.key,
    required this.sliderKey,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final Key sliderKey;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  State<_SubtitleSettingSlider> createState() => _SubtitleSettingSliderState();
}

class _SubtitleSettingSliderState extends State<_SubtitleSettingSlider> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  void didUpdateWidget(covariant _SubtitleSettingSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        Slider(
          key: widget.sliderKey,
          value: _value.clamp(widget.min, widget.max),
          min: widget.min,
          max: widget.max,
          divisions: widget.divisions,
          onChanged: (value) {
            setState(() => _value = value);
            widget.onChanged(value);
          },
        ),
      ],
    );
  }
}
