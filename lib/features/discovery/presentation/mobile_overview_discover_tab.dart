import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/shared/discovery_overview_content.dart';

class MobileOverviewDiscoverTab extends StatelessWidget {
  const MobileOverviewDiscoverTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const DiscoveryOverviewContent(mobile: true, previewSize: 10);
  }
}
