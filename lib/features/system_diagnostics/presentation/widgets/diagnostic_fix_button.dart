import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/configuration_tab_request_provider.dart';
import 'package:sakuramedia/features/system_diagnostics/data/diagnostic_fix_target.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';

/// 「去修复 →」跳转按钮：把目标分类写入一次性请求信号，再跳到配置页。
///
/// 配置页是主路由分支的常驻页面，跳转本身不会重建它；请求信号由配置页消费并
/// 清空，保证跳转后落在正确的分类上。
class DiagnosticFixButton extends ConsumerWidget {
  const DiagnosticFixButton({super.key, required this.target});

  final DiagnosticFixTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppButton(
      label: AppLocalizations.of(context).diagnosticFixAction,
      variant: AppButtonVariant.secondary,
      size: AppButtonSize.small,
      trailingIcon: const Icon(Icons.arrow_forward),
      onPressed: () {
        ref
            .read(configurationTabRequestProvider.notifier)
            .request(target.configurationTabKey);
        context.goPrimary(AppRouteId.desktopConfiguration);
      },
    );
  }
}
