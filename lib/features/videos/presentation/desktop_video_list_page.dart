import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_page_state_cache_keys.dart';
import 'package:sakuramedia/app/cached_page_state_handle.dart';
import 'package:sakuramedia/features/tags/data/tags_api.dart';
import 'package:sakuramedia/features/tags/presentation/tag_selector_panel.dart';
import 'package:sakuramedia/features/videos/data/persons_api.dart';
import 'package:sakuramedia/features/videos/data/videos_api.dart';
import 'package:sakuramedia/features/videos/presentation/person_selector_panel.dart';
import 'package:sakuramedia/features/videos/presentation/video_edit_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/video_import_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/video_list_content.dart';
import 'package:sakuramedia/features/videos/presentation/video_list_page_state.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';

class DesktopVideoListPage extends StatefulWidget {
  const DesktopVideoListPage({super.key});

  @override
  State<DesktopVideoListPage> createState() => _DesktopVideoListPageState();
}

class _DesktopVideoListPageState extends State<DesktopVideoListPage> {
  late final CachedPageStateHandle<VideoListPageStateEntry> _pageStateHandle;
  late final TextEditingController _searchController;

  VideoListPageStateEntry get _pageState => _pageStateHandle.value;

  @override
  void initState() {
    super.initState();
    _pageStateHandle = obtainCachedPageState<VideoListPageStateEntry>(
      context,
      key: desktopVideosPageStateKey(),
      create: () => VideoListPageStateEntry(
        videosApi: context.read<VideosApi>(),
        tagsApi: context.read<TagsApi>(),
        personsApi: context.read<PersonsApi>(),
      ),
    );
    _searchController = TextEditingController(text: _pageState.query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageStateHandle.dispose();
    super.dispose();
  }

  void _applySort(VideoFilterState next) {
    if (next.matches(_pageState.filterState)) {
      return;
    }
    setState(() {
      _pageState.filterState = next;
    });
    _pageState.reloadVideos();
  }

  void _applyQuery(String value) {
    final trimmed = value.trim();
    if (trimmed == _pageState.query) {
      return;
    }
    _pageState.query = trimmed;
    _pageState.reloadVideos();
  }

  Future<void> _createVideo() async {
    final created = await showVideoEditDialog(context);
    if (created != null) {
      _pageState.reloadVideos();
    }
  }

  Future<void> _importVideos() async {
    final result = await showVideoImportDialog(context);
    if (result != null) {
      if (mounted) {
        showToast('导入完成：新增 ${result.createdCount}，跳过 ${result.skippedCount}');
      }
      _pageState.reloadVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageState = _pageState;
    final tagSelection = pageState.tagSelection;
    final personSelection = pageState.personSelection;

    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: SingleChildScrollView(
        controller: pageState.controller.scrollController,
        child: Column(
          key: const Key('videos-page'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    fieldKey: const Key('videos-search-field'),
                    controller: _searchController,
                    hintText: '搜索视频标题',
                    prefix: Icon(
                      Icons.search,
                      size: context.appComponentTokens.iconSizeSm,
                      color: context.appTextPalette.secondary,
                    ),
                    suffix: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(
                              Icons.close,
                              size: context.appComponentTokens.iconSizeSm,
                            ),
                            splashRadius: 16,
                            onPressed: () {
                              _searchController.clear();
                              _applyQuery('');
                            },
                          ),
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: _applyQuery,
                  ),
                ),
                SizedBox(width: context.appSpacing.md),
                AppButton(
                  key: const Key('videos-create-button'),
                  label: '新建视频',
                  variant: AppButtonVariant.primary,
                  onPressed: _createVideo,
                ),
                SizedBox(width: context.appSpacing.sm),
                AppButton(
                  key: const Key('videos-import-button'),
                  label: '导入',
                  variant: AppButtonVariant.secondary,
                  onPressed: _importVideos,
                ),
              ],
            ),
            SizedBox(height: context.appSpacing.lg),
            AnimatedBuilder(
              animation: tagSelection,
              builder: (context, _) => TagSelectorPanel(
                selection: tagSelection,
                onToggleTag: (tagId) {
                  tagSelection.toggle(tagId);
                  pageState.reloadVideos();
                },
                onRemoveTag: (tagId) {
                  tagSelection.remove(tagId);
                  pageState.reloadVideos();
                },
                onClear: () {
                  tagSelection.clear();
                  pageState.reloadVideos();
                },
                onQueryChanged: tagSelection.setQuery,
                onToggleExpanded: tagSelection.toggleExpanded,
                // 视频域多标签固定 OR（后端无 tag_match），隐藏匹配模式开关。
                onMatchModeChanged: (_) {},
                showMatchModeToggle: false,
                onRetry: () => unawaited(tagSelection.retry()),
              ),
            ),
            SizedBox(height: context.appSpacing.lg),
            AnimatedBuilder(
              animation: personSelection,
              builder: (context, _) => PersonSelectorPanel(
                selection: personSelection,
                onTogglePerson: (person) {
                  personSelection.toggle(person);
                  pageState.reloadVideos();
                },
                onRemovePerson: (personId) {
                  personSelection.remove(personId);
                  pageState.reloadVideos();
                },
                onClear: () {
                  personSelection.clear();
                  pageState.reloadVideos();
                },
                onQueryChanged: personSelection.setQuery,
                onRetry: () => unawaited(personSelection.retry()),
              ),
            ),
            SizedBox(height: context.appSpacing.lg),
            VideoListContent(
              controller: pageState.controller,
              filterState: pageState.filterState,
              onFilterChanged: _applySort,
              contentKey: const Key('videos-page-list'),
              totalKey: const Key('videos-page-total'),
              sectionSpacing: context.appSpacing.lg,
              onVideoTap: (video) =>
                  context.go('$desktopVideosPath/${video.id}'),
            ),
          ],
        ),
      ),
    );
  }
}
