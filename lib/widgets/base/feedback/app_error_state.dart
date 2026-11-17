import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

export 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart'
    show AppEmptyStateRetryStyle, AppStatePanelVariant;

/// 共享错误态：标题 + 说明 + 可选重试，布局复用 [AppEmptyState]。
///
/// 错误和空态是两种语义，页面不要再用空态组件表达失败。
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.variant = AppStatePanelVariant.page,
    this.retryStyle = AppEmptyStateRetryStyle.primary,
    this.retryLabel,
    this.retryKey,
    this.icon = Icons.error_outline_rounded,
  });

  /// 单行错误提示：没有标题，失败说明和重试按钮保持在同一行。
  const AppErrorState.inline({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
    this.retryKey,
  }) : title = '',
       variant = AppStatePanelVariant.inline,
       retryStyle = AppEmptyStateRetryStyle.text,
       icon = Icons.error_outline_rounded;

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final AppStatePanelVariant variant;
  final AppEmptyStateRetryStyle retryStyle;
  final String? retryLabel;
  final Key? retryKey;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: title,
      message: message,
      icon: icon,
      onRetry: onRetry,
      variant: variant,
      retryStyle: retryStyle,
      retryLabel: retryLabel,
      retryKey: retryKey,
    );
  }
}
