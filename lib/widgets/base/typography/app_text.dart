import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    required this.size,
    this.weight = AppTextWeight.regular,
    this.tone = AppTextTone.primary,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
  });

  final String data;
  final AppTextSize size;
  final AppTextWeight weight;
  final AppTextTone tone;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
      style: resolveAppTextStyle(
        context,
        size: size,
        weight: weight,
        tone: tone,
      ),
    );
  }
}
