import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/download_selection_policy_content.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/download_selection_policy_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';

class MobileDownloadSelectionPolicyPage extends ConsumerStatefulWidget {
  const MobileDownloadSelectionPolicyPage({super.key});

  @override
  ConsumerState<MobileDownloadSelectionPolicyPage> createState() =>
      _MobileDownloadSelectionPolicyPageState();
}

class _MobileDownloadSelectionPolicyPageState
    extends ConsumerState<MobileDownloadSelectionPolicyPage> {
  AppMobileSubpageBackInterceptorController? _backInterceptor;
  late final AppMobileSubpageBackHandler _backHandler = _handleBack;
  bool _dirty = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final interceptor = AppMobileSubpageBackInterceptor.maybeOf(context);
    if (identical(interceptor, _backInterceptor)) return;
    final previous = _backInterceptor;
    previous?.detach(_backHandler);
    _backInterceptor = interceptor;
    interceptor?.attach(_backHandler);
    interceptor?.setCanPop(!_dirty);
  }

  @override
  void dispose() {
    _backInterceptor?.detach(_backHandler);
    super.dispose();
  }

  Future<bool> _handleBack() async {
    if (!_dirty) return true;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.downloadSelectionDiscardTitle,
      message: l10n.downloadSelectionDiscardMessage,
      confirmLabel: l10n.downloadSelectionDiscardConfirm,
      danger: true,
      dialogKey: const Key('download-selection-discard-dialog'),
      confirmKey: const Key('download-selection-discard-confirm'),
    );
    if (!mounted || !confirmed) return false;
    setState(() => _dirty = false);
    _backInterceptor?.setCanPop(true);
    ref.read(downloadSelectionPolicyProvider.notifier).discardDraft();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('mobile-settings-download-selection'),
      child: DownloadSelectionPolicyContent(
        mobile: true,
        onDirtyChanged: (dirty) {
          if (!mounted || _dirty == dirty) return;
          setState(() => _dirty = dirty);
          _backInterceptor?.setCanPop(!dirty);
        },
      ),
    );
  }
}
