import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/discovery/data/taste_profile_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/taste/taste_actress_rail.dart';
import 'package:sakuramedia/widgets/domain/taste/taste_section_label.dart';

/// 「小标题 + 女优 rail」的统一区块，已订阅和推荐共用。
class TasteActressSection extends StatelessWidget {
  const TasteActressSection({
    super.key,
    required this.title,
    required this.entries,
    this.onActorTap,
    this.onFollowTap,
    this.isFollowUpdating,
  });

  final String title;
  final List<TasteProfileActressDto> entries;
  final ValueChanged<TasteProfileActressDto>? onActorTap;
  final ValueChanged<TasteProfileActressDto>? onFollowTap;
  final bool Function(TasteProfileActressDto entry)? isFollowUpdating;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TasteSectionLabel(label: title),
        SizedBox(height: context.appSpacing.sm),
        TasteActressRail(
          entries: entries,
          onActorTap: onActorTap,
          onFollowTap: onFollowTap,
          isFollowUpdating: isFollowUpdating,
        ),
      ],
    );
  }
}
