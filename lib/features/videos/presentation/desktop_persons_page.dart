import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/videos/data/person_dto.dart';
import 'package:sakuramedia/features/videos/data/persons_api.dart';
import 'package:sakuramedia/features/videos/presentation/person_edit_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/persons_overview_controller.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

const Map<int, String> _genderLabels = <int, String>{0: '未知', 1: '女', 2: '男'};

class DesktopPersonsPage extends StatefulWidget {
  const DesktopPersonsPage({super.key});

  @override
  State<DesktopPersonsPage> createState() => _DesktopPersonsPageState();
}

class _DesktopPersonsPageState extends State<DesktopPersonsPage> {
  late final PersonsOverviewController _controller;
  late final PersonsApi _personsApi;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _personsApi = context.read<PersonsApi>();
    _controller = PersonsOverviewController(
      fetchPage: (page, pageSize) => _personsApi.getPersons(
        query: _query.isEmpty ? null : _query,
        page: page,
        pageSize: pageSize,
      ),
    );
    _controller.attachScrollListener();
    _controller.initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _applyQuery(String value) {
    final trimmed = value.trim();
    if (trimmed == _query) {
      return;
    }
    _query = trimmed;
    if (_controller.scrollController.hasClients) {
      _controller.scrollController.jumpTo(0);
    }
    unawaited(_controller.reload());
  }

  Future<void> _createPerson() async {
    final created = await showPersonEditDialog(context);
    if (created != null) {
      unawaited(_controller.reload());
    }
  }

  Future<void> _editPerson(PersonDto person) async {
    final updated = await showPersonEditDialog(context, existing: person);
    if (updated != null) {
      unawaited(_controller.reload());
    }
  }

  Future<void> _deletePerson(PersonDto person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除人物'),
        content: Text('确定删除「${person.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _personsApi.deletePerson(person.id);
      _controller.removeItem(person.id);
      if (mounted) {
        showToast('已删除');
      }
    } catch (_) {
      if (mounted) {
        showToast('删除失败，请稍后重试');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: SingleChildScrollView(
        controller: _controller.scrollController,
        padding: EdgeInsets.all(context.appSpacing.lg),
        child: Column(
          key: const Key('persons-page'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    fieldKey: const Key('persons-page-search-field'),
                    controller: _searchController,
                    hintText: '搜索人物',
                    prefix: Icon(
                      Icons.search,
                      size: context.appComponentTokens.iconSizeSm,
                      color: context.appTextPalette.secondary,
                    ),
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: _applyQuery,
                  ),
                ),
                SizedBox(width: context.appSpacing.md),
                AppButton(
                  key: const Key('persons-page-create-button'),
                  label: '新建人物',
                  variant: AppButtonVariant.primary,
                  onPressed: _createPerson,
                ),
              ],
            ),
            SizedBox(height: context.appSpacing.lg),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final showFooter = _controller.items.isNotEmpty &&
                    (_controller.isLoadingMore ||
                        _controller.loadMoreErrorMessage != null);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppFilterTotalHeader(
                      leading: const SizedBox.shrink(),
                      totalText: '${_controller.total} 人',
                      totalKey: const Key('persons-page-total'),
                    ),
                    SizedBox(height: context.appSpacing.md),
                    _buildGrid(context),
                    if (showFooter) ...[
                      SizedBox(height: context.appSpacing.md),
                      AppPagedLoadMoreFooter(
                        isLoading: _controller.isLoadingMore,
                        errorMessage: _controller.loadMoreErrorMessage,
                        onRetry: _controller.loadMore,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    if (_controller.isInitialLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ));
    }
    final error = _controller.initialErrorMessage;
    if (error != null) {
      return AppEmptyState(message: error);
    }
    if (_controller.items.isEmpty) {
      return const AppEmptyState(message: '暂无人物，点击「新建人物」添加');
    }
    return Wrap(
      spacing: context.appSpacing.md,
      runSpacing: context.appSpacing.md,
      children: [
        for (final person in _controller.items)
          _PersonCard(
            person: person,
            onTap: () =>
                context.go('$desktopPersonsPath/${person.id}'),
            onEdit: () => _editPerson(person),
            onDelete: () => _deletePerson(person),
          ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final PersonDto person;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = person.avatarImage?.bestAvailableUrl;
    return SizedBox(
      width: 220,
      child: Container(
        key: Key('person-card-${person.id}'),
        padding: EdgeInsets.all(context.appSpacing.md),
        decoration: BoxDecoration(
          color: context.appColors.surfaceCard,
          borderRadius: context.appRadius.lgBorder,
          border: Border.all(color: context.appColors.borderSubtle),
          boxShadow: context.appShadows.card,
        ),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 48,
                height: 48,
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? MaskedImage(url: avatarUrl, fit: BoxFit.cover)
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.appColors.surfaceMuted,
                        ),
                        child: Icon(
                          Icons.person_outline,
                          color: context.appTextPalette.muted,
                        ),
                      ),
              ),
            ),
            SizedBox(width: context.appSpacing.sm),
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.medium,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    Text(
                      '${_genderLabels[person.gender] ?? '未知'} · ${person.videoCount} 个视频',
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              iconSize: context.appComponentTokens.iconSizeSm,
              tooltip: '编辑',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              iconSize: context.appComponentTokens.iconSizeSm,
              tooltip: '删除',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
