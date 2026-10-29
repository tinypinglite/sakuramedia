import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/download_selection_policy_content.dart';

class DownloadSelectionPolicySection extends StatelessWidget {
  const DownloadSelectionPolicySection({
    super.key,
    required this.active,
    this.onDirtyChanged,
  });

  final bool active;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();
    return DownloadSelectionPolicyContent(
      mobile: false,
      onDirtyChanged: onDirtyChanged,
    );
  }
}
