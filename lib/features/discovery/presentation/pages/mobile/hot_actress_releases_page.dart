import 'package:flutter/material.dart';
import 'package:sakuramedia/features/discovery/presentation/pages/shared/discovery_recommendation_content.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';

class MobileHotActressReleasesPage extends StatelessWidget {
  const MobileHotActressReleasesPage({super.key});

  @override
  Widget build(BuildContext context) => HotActressReleasesContent(
    pageSize: 18,
    keyPrefix: 'mobile-hot-actress-releases',
    headerGap: context.appSpacing.md,
    backgroundColor: context.appColors.surfaceCard,
    placeholderCount: 6,
    basePath: mobileMoviesPath,
    enablePullToRefresh: true,
  );
}
