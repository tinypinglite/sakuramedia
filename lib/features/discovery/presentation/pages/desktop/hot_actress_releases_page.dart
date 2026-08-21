import 'package:flutter/material.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/shared/discovery_recommendation_content.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';

class DesktopHotActressReleasesPage extends StatelessWidget {
  const DesktopHotActressReleasesPage({super.key});

  @override
  Widget build(BuildContext context) => HotActressReleasesContent(
    pageSize: 24,
    keyPrefix: 'desktop-hot-actress-releases',
    headerGap: context.appSpacing.lg,
    backgroundColor: context.appColors.surfaceElevated,
    placeholderCount: 12,
    basePath: desktopMoviesPath,
  );
}
