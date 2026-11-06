import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

/// 移动端 section 级错误态卡片。
///
/// 跟桌面版 [`AppSectionError`](app_section_error.dart) 是姊妹关系——
/// 桌面无卡壳、左对齐；移动有卡壳、内容居中。
/// 参数 `{title, message, onRetry}` 与桌面版对齐，方便调用方复用文案。
class AppMobileSectionError extends StatelessWidget {
  const AppMobileSectionError({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryButtonKey,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;
  final Key? retryButtonKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: AppEmptyState(
        title: title,
        message: message,
        retryKey: retryButtonKey,
        onRetry: () => onRetry(),
      ),
    );
  }
}
