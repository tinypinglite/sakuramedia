import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/discovery/data/taste_profile_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/taste/taste_actress_card.dart';

/// 口味女优横向 rail；所有入口统一使用 [TasteActressCard]。
class TasteActressRail extends StatelessWidget {
  const TasteActressRail({
    super.key,
    required this.entries,
    this.onActorTap,
    this.onFollowTap,
    this.isFollowUpdating,
  });

  final List<TasteProfileActressDto> entries;
  final ValueChanged<TasteProfileActressDto>? onActorTap;
  final ValueChanged<TasteProfileActressDto>? onFollowTap;
  final bool Function(TasteProfileActressDto entry)? isFollowUpdating;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final spacing = context.appSpacing;
    return SingleChildScrollView(
      key: const Key('taste-actress-rail'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (var index = 0; index < entries.length; index++) ...<Widget>[
            if (index > 0) SizedBox(width: spacing.sm),
            TasteActressCard(
              entry: entries[index],
              isFollowUpdating: isFollowUpdating?.call(entries[index]) ?? false,
              onTap: onActorTap == null
                  ? null
                  : () => onActorTap!(entries[index]),
              onFollowTap: onFollowTap == null
                  ? null
                  : () => onFollowTap!(entries[index]),
            ),
          ],
        ],
      ),
    );
  }
}
