import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

/// 移动端 section 级错误态卡片。
///
/// 跟桌面版 [`AppSectionError`](app_section_error.dart) 是姊妹关系——
/// 桌面无卡壳；移动有卡壳。两者共用 section 级 [AppErrorState] 布局。
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
    return AppContentCard(
      padding: EdgeInsets.zero,
      child: AppErrorState(
        title: title,
        message: message,
        variant: AppStatePanelVariant.section,
        retryKey: retryButtonKey,
        onRetry: () => onRetry(),
      ),
    );
  }
}
