import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';

/// 概览卡片的统一错误行：复用共享内联错误条。
class OverviewCardErrorRow extends StatelessWidget {
  const OverviewCardErrorRow({
    super.key,
    required this.message,
    this.onRetry,
    this.retryKey,
  });

  final String message;
  final VoidCallback? onRetry;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;
    return AppInlineErrorBanner(
      message: message,
      onRetry: retry == null ? null : () async => retry(),
      retryKey: retryKey,
    );
  }
}
