import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/mobile/mobile_config_empty_card.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_section_error.dart';

/// 配置页移动端的统一列表体：loading / error / empty / 卡片列表。
class MobileConfigListBody<T> extends StatelessWidget {
  const MobileConfigListBody({
    super.key,
    required this.loading,
    required this.error,
    required this.items,
    required this.loadingBuilder,
    required this.errorTitle,
    required this.errorMessage,
    required this.emptyMessage,
    required this.onRetry,
    required this.cardBuilder,
    this.emptyKey,
    this.errorKey,
    this.retryKey,
  });

  final bool loading;
  final Object? error;
  final List<T> items;
  final WidgetBuilder loadingBuilder;
  final String errorTitle;
  final String errorMessage;
  final String emptyMessage;
  final Future<void> Function() onRetry;
  final Widget Function(BuildContext context, T item) cardBuilder;
  final Key? emptyKey;
  final Key? errorKey;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return loadingBuilder(context);
    }
    if (error != null) {
      return AppMobileSectionError(
        key: errorKey,
        title: errorTitle,
        message: errorMessage,
        onRetry: onRetry,
        retryButtonKey: retryKey,
      );
    }
    if (items.isEmpty) {
      return MobileConfigEmptyCard(key: emptyKey, message: emptyMessage);
    }
    final spacing = context.appSpacing.sm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) SizedBox(height: spacing),
          cardBuilder(context, items[index]),
        ],
      ],
    );
  }
}
