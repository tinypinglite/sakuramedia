import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/media/providers/player_subtitle_preference_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

Future<void> showMoviePlayerSubtitleSettings(BuildContext context) {
  return showAppAdaptiveModal<void>(
    context: context,
    modalKey: const Key('movie-player-subtitle-settings-modal'),
    desktopWidth: 420,
    desktopHeight: 380,
    builder: (_) => const _MoviePlayerSubtitleSettings(),
  );
}

class _MoviePlayerSubtitleSettings extends ConsumerWidget {
  const _MoviePlayerSubtitleSettings();

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
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.moviePlayerSubtitleSettingsTitle,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s16,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.lg),
          _SubtitleSettingSlider(
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
            label:
                '${l10n.moviePlayerSubtitlePositionLabel}  '
                '${preference.bottomOffset.round()}',
            value: preference.bottomOffset,
            min: PlayerSubtitlePreference.minBottomOffset,
            max: PlayerSubtitlePreference.maxBottomOffset,
            divisions: 24,
            onChanged: controller.setBottomOffset,
          ),
          SizedBox(height: spacing.lg),
          Row(
            children: [
              AppTextButton(
                key: const Key('movie-player-subtitle-settings-reset'),
                label: l10n.moviePlayerSubtitleSettingsReset,
                size: AppTextButtonSize.small,
                onPressed: controller.reset,
              ),
              const Spacer(),
              AppButton(
                key: const Key('movie-player-subtitle-settings-done'),
                label: l10n.moviePlayerSubtitleSettingsDone,
                size: AppButtonSize.small,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubtitleSettingSlider extends StatefulWidget {
  const _SubtitleSettingSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

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
