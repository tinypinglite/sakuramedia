import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

class ActorAvatar extends StatelessWidget {
  const ActorAvatar({
    super.key,
    required this.imageUrl,
    required this.size,
    this.placeholderKey,
  });

  final String? imageUrl;
  final double size;
  final Key? placeholderKey;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child:
            hasImage
                ? MaskedImage(url: imageUrl!, fit: BoxFit.cover)
                : DecoratedBox(
                  key: placeholderKey,
                  decoration: BoxDecoration(
                    color: context.appColors.movieDetailEmptyBackground,
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: context.appColors.textMuted,
                  ),
                ),
      ),
    );
  }
}
