import 'package:flutter/material.dart';
import 'package:sakuramedia/features/moments/presentation/moments_page.dart';

class DesktopMomentsPage extends StatelessWidget {
  const DesktopMomentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MomentsPage(platform: MomentsPagePlatform.desktop);
  }
}
