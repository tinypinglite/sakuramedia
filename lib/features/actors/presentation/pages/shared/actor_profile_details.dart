import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';

class ActorProfileDetails extends StatefulWidget {
  const ActorProfileDetails({
    super.key,
    required this.actor,
    required this.compact,
  });

  final ActorDetailDto actor;
  final bool compact;

  @override
  State<ActorProfileDetails> createState() => _ActorProfileDetailsState();
}

class _ActorProfileDetailsState extends State<ActorProfileDetails> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant ActorProfileDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actor.summary.id != widget.actor.summary.id) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = widget.actor;
    final birthday = actor.birthday;
    final l10n = AppLocalizations.of(context);
    final age = actor.age == null ? null : l10n.actorAgeValue(actor.age!);
    final fields = <(String, String)>[
      if (birthday != null)
        (
          l10n.actorBirthdayLabel,
          '${l10n.actorBirthdayValue(birthday.year, birthday.month, birthday.day)}'
              '${age == null ? '' : ' · $age'}',
        )
      else if (age != null)
        (l10n.actorAgeLabel, age),
      if (actor.birthplace != null)
        (l10n.actorBirthplaceLabel, actor.birthplace!),
      if (actor.bloodType != null) (l10n.actorBloodTypeLabel, actor.bloodType!),
      if (actor.heightCm != null)
        (l10n.actorHeightLabel, '${actor.heightCm} cm'),
      if (actor.cup != null) (l10n.actorCupLabel, actor.cup!),
      if (actor.bustCm != null) (l10n.actorBustLabel, '${actor.bustCm} cm'),
      if (actor.waistCm != null) (l10n.actorWaistLabel, '${actor.waistCm} cm'),
      if (actor.hipsCm != null) (l10n.actorHipsLabel, '${actor.hipsCm} cm'),
    ];
    if (fields.isEmpty) return const SizedBox.shrink();

    final summary = <(String, String)>[
      if (age != null) (l10n.actorAgeLabel, age),
      if (actor.heightCm != null)
        (l10n.actorHeightLabel, '${actor.heightCm} cm'),
      if (actor.cup != null) (l10n.actorCupLabel, actor.cup!),
    ];
    // 只有出生地等少量资料时直接显示，避免空摘要和无意义的展开操作。
    if (summary.isEmpty) summary.addAll(fields.take(3));
    final hasMore = fields.any((field) => !summary.contains(field));
    final visible = widget.compact && !_expanded ? summary : fields;
    final spacing = context.appSpacing;
    final details = SelectionArea(
      child: Wrap(
        spacing: spacing.lg,
        runSpacing: spacing.xs,
        children: [
          for (final (label, value) in visible)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label  ',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s10,
                      tone: AppTextTone.muted,
                    ),
                  ),
                  TextSpan(text: value),
                ],
              ),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s10,
                tone: AppTextTone.secondary,
              ),
            ),
        ],
      ),
    );
    return Padding(
      key: const Key('actor-profile-details'),
      padding: EdgeInsets.only(top: widget.compact ? spacing.sm : spacing.xs),
      child: widget.compact && hasMore
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: spacing.xs),
                    child: details,
                  ),
                ),
                SizedBox(width: spacing.sm),
                AppIconButton(
                  key: const Key('actor-profile-toggle'),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  size: AppIconButtonSize.mini,
                  tooltip: _expanded
                      ? AppLocalizations.of(context).actorProfileCollapseTooltip
                      : AppLocalizations.of(context).actorProfileExpandTooltip,
                  semanticLabel: _expanded
                      ? AppLocalizations.of(context).actorProfileCollapseTooltip
                      : AppLocalizations.of(context).actorProfileExpandTooltip,
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            )
          : details,
    );
  }
}
