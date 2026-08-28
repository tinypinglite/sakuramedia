import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

/// 桌面端以图搜图「选择女优」弹窗。
Future<List<ActorListItemDto>?> showActorSelectorDialog(
  BuildContext context, {
  required List<ActorListItemDto> actors,
  required List<ActorListItemDto> initialSelectedActors,
}) {
  return showDialog<List<ActorListItemDto>>(
    context: context,
    builder: (dialogContext) => AppDesktopDialog(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 780),
      child: ImageSearchActorSelectorBody(
        actors: actors,
        initialSelectedActors: initialSelectedActors,
        onCancel: () => Navigator.of(dialogContext).pop(),
        onDone: (selected) => Navigator.of(dialogContext).pop(selected),
      ),
    ),
  );
}

class ImageSearchActorSelectorBody extends StatefulWidget {
  const ImageSearchActorSelectorBody({
    super.key,
    required this.actors,
    required this.initialSelectedActors,
    required this.onCancel,
    required this.onDone,
  });

  final List<ActorListItemDto> actors;
  final List<ActorListItemDto> initialSelectedActors;
  final VoidCallback onCancel;
  final ValueChanged<List<ActorListItemDto>> onDone;

  @override
  State<ImageSearchActorSelectorBody> createState() =>
      _ImageSearchActorSelectorBodyState();
}

class _ImageSearchActorSelectorBodyState
    extends State<ImageSearchActorSelectorBody> {
  late final Set<int> _selectedActorIds;

  @override
  void initState() {
    super.initState();
    _selectedActorIds = widget.initialSelectedActors
        .map((ActorListItemDto actor) => actor.id)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '已选 ${_selectedActorIds.length} 位',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s18,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(_selectedActorIds.clear),
              child: const Text('清空'),
            ),
          ],
        ),
        SizedBox(height: spacing.lg),
        Expanded(
          child: ListView.separated(
            itemCount: widget.actors.length,
            separatorBuilder: (context, index) => SizedBox(height: spacing.sm),
            itemBuilder: (context, index) {
              final actor = widget.actors[index];
              final selected = _selectedActorIds.contains(actor.id);
              return InkWell(
                key: Key('desktop-image-search-actor-option-${actor.id}'),
                borderRadius: context.appRadius.mdBorder,
                onTap: () => setState(() {
                  if (selected) {
                    _selectedActorIds.remove(actor.id);
                  } else {
                    _selectedActorIds.add(actor.id);
                  }
                }),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.lg,
                    vertical: spacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceCard,
                    borderRadius: context.appRadius.mdBorder,
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : context.appColors.borderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          actor.displayName,
                          style: resolveAppTextStyle(
                            context,
                            size: AppTextSize.s14,
                            weight: AppTextWeight.regular,
                            tone: AppTextTone.primary,
                          ),
                        ),
                      ),
                      Checkbox(value: selected, onChanged: (_) {}),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: spacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(label: '取消', onPressed: widget.onCancel),
            SizedBox(width: spacing.sm),
            AppButton(
              label: '完成',
              variant: AppButtonVariant.primary,
              onPressed: () => widget.onDone(
                widget.actors
                    .where(
                      (ActorListItemDto actor) =>
                          _selectedActorIds.contains(actor.id),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
