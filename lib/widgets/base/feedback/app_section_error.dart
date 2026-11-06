import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';

/// 桌面 section 级错误态：无卡壳，内容使用共享 section 布局。
class AppSectionError extends StatelessWidget {
  const AppSectionError({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => AppErrorState(
    title: title,
    message: message,
    onRetry: onRetry,
    variant: AppStatePanelVariant.section,
  );
}
