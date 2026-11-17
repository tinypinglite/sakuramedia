import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

enum CollectionHintBoxVariant { empty, error }

/// 合集横滑区的轻量提示条：用于空态与加载失败的文案占位。
///
/// 切片 / 视频 / 时刻三个合集横滑区共用，避免各页面各写一份同构容器。
class CollectionHintBox extends StatelessWidget {
  const CollectionHintBox({
    super.key,
    required this.message,
    this.variant = CollectionHintBoxVariant.empty,
    this.onRetry,
    this.retryKey,
  }) : assert(
         variant == CollectionHintBoxVariant.empty || onRetry != null,
         'error variant 必须提供 onRetry',
       );

  /// 加载失败提示：始终带重试动作，和普通空态区分。
  const CollectionHintBox.error({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryKey,
  }) : variant = CollectionHintBoxVariant.error;

  final String message;
  final CollectionHintBoxVariant variant;
  final VoidCallback? onRetry;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final isError = variant == CollectionHintBoxVariant.error;
    return AppContentCard(
      padding: EdgeInsets.all(context.appSpacing.md),
      borderRadius: context.appRadius.mdBorder,
      backgroundColor: isError ? context.appColors.errorSurface : null,
      child: isError
          ? AppErrorState.inline(
              message: message,
              onRetry: onRetry,
              retryKey: retryKey,
            )
          : Text(
              message,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
    );
  }
}
