import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_glass_search_field.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_wrap.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';

typedef CollectionListCardBuilder<T> =
    Widget Function(
      BuildContext context,
      T collection, {
      required VoidCallback onTap,
      required VoidCallback onEdit,
      required VoidCallback onDelete,
    });

/// 合集列表的共享页面壳：搜索、桌面/移动顶栏、加载/错误/空态、懒加载网格。
///
/// 数据来源和新建/编辑/删除仍由各业务域提供；本组件只统一视觉和交互骨架。
class CollectionListContent<T> extends ConsumerStatefulWidget {
  const CollectionListContent({
    super.key,
    required this.mobile,
    required this.keyPrefix,
    required this.title,
    required this.searchHint,
    required this.createLabel,
    required this.emptyDesktopMessage,
    required this.emptyMobileMessage,
    required this.noMatchMessage,
    required this.loadErrorMessage,
    required this.collections,
    required this.onRefresh,
    required this.placeholders,
    required this.nameOf,
    required this.cardBuilder,
    required this.onOpen,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
  });

  final bool mobile;
  final String keyPrefix;
  final String title;
  final String searchHint;
  final String createLabel;
  final String emptyDesktopMessage;
  final String emptyMobileMessage;
  final String noMatchMessage;
  final String loadErrorMessage;
  final AsyncValue<List<T>> collections;
  final Future<void> Function() onRefresh;
  final List<T> Function(bool mobile) placeholders;
  final String Function(T collection) nameOf;
  final CollectionListCardBuilder<T> cardBuilder;
  final Future<void> Function(BuildContext context, T collection) onOpen;
  final Future<void> Function(BuildContext context) onCreate;
  final Future<void> Function(BuildContext context, T collection) onEdit;
  final Future<void> Function(BuildContext context, T collection) onDelete;

  @override
  ConsumerState<CollectionListContent<T>> createState() =>
      _CollectionListContentState<T>();
}

class _CollectionListContentState<T>
    extends ConsumerState<CollectionListContent<T>> {
  final _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isLoading =>
      widget.collections.isLoading && widget.collections.value == null;

  List<T> _allCollections() {
    if (_isLoading) {
      return widget.placeholders(widget.mobile);
    }
    return widget.collections.value ?? <T>[];
  }

  List<T> _visibleCollections(List<T> allCollections) {
    if (_keyword.isEmpty) {
      return allCollections;
    }
    return allCollections
        .where(
          (collection) =>
              widget.nameOf(collection).toLowerCase().contains(_keyword),
        )
        .toList(growable: false);
  }

  void _onSearchChanged(String value) {
    setState(() => _keyword = value.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final allCollections = _allCollections();
    final visibleCollections = _visibleCollections(allCollections);
    final page = Column(
      key: Key('${widget.keyPrefix}-page'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.mobile)
          _buildMobileHeader(context)
        else
          _buildDesktopHeader(context),
        Expanded(
          child: _buildBody(
            context,
            allCollections: allCollections,
            visibleCollections: visibleCollections,
          ),
        ),
      ],
    );
    if (widget.mobile) {
      return page;
    }
    return AppPageRefreshScope(onRefresh: widget.onRefresh, child: page);
  }

  Widget _buildDesktopHeader(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.sm),
        AppSurfaceGroup(
          child: Row(
            children: [
              Expanded(
                child: AppGlassSearchField(
                  controller: _searchController,
                  hintText: widget.searchHint,
                  fieldKey: Key('${widget.keyPrefix}-search-field'),
                  clearKey: Key('${widget.keyPrefix}-search-clear'),
                  onChanged: _onSearchChanged,
                ),
              ),
              SizedBox(width: spacing.md),
              AppGlassHeaderGroup(
                children: [
                  AppGlassHeaderButton(
                    key: Key('${widget.keyPrefix}-create-button'),
                    icon: Icons.add_rounded,
                    label: widget.createLabel,
                    onTap: () => unawaited(widget.onCreate(context)),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: spacing.lg),
      ],
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    final spacing = context.appSpacing;
    return Padding(
      padding: EdgeInsets.only(top: spacing.sm),
      child: Row(
        children: [
          Expanded(
            child: AppGlassSearchField(
              controller: _searchController,
              hintText: widget.searchHint,
              fieldKey: Key('${widget.keyPrefix}-search-field'),
              clearKey: Key('${widget.keyPrefix}-search-clear'),
              onChanged: _onSearchChanged,
            ),
          ),
          SizedBox(width: spacing.sm),
          AppGlassIconButton(
            key: Key('${widget.keyPrefix}-create-button'),
            tooltip: widget.createLabel,
            icon: Icons.add_rounded,
            onPressed: () => unawaited(widget.onCreate(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required List<T> allCollections,
    required List<T> visibleCollections,
  }) {
    final scroll = _buildScrollView(
      context,
      allCollections: allCollections,
      visibleCollections: visibleCollections,
    );
    return AppSkeletonizer(enabled: _isLoading, child: scroll);
  }

  Widget _buildScrollView(
    BuildContext context, {
    required List<T> allCollections,
    required List<T> visibleCollections,
  }) {
    final slivers = _buildSlivers(
      context,
      allCollections: allCollections,
      visibleCollections: visibleCollections,
    );
    if (widget.mobile) {
      return AppAdaptiveRefreshScrollView(
        key: Key('${widget.keyPrefix}-scroll'),
        onRefresh: widget.onRefresh,
        slivers: slivers,
      );
    }
    return CustomScrollView(
      key: Key('${widget.keyPrefix}-scroll'),
      slivers: slivers,
    );
  }

  List<Widget> _buildSlivers(
    BuildContext context, {
    required List<T> allCollections,
    required List<T> visibleCollections,
  }) {
    final l10n = AppLocalizations.of(context);
    final error = widget.collections.error;
    if (!_isLoading && error != null && allCollections.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
            message: apiErrorMessage(
              error,
              fallback: widget.loadErrorMessage,
              l10n: l10n,
            ),
          ),
        ),
      ];
    }
    if (allCollections.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
            message: widget.mobile
                ? widget.emptyMobileMessage
                : widget.emptyDesktopMessage,
          ),
        ),
      ];
    }
    if (visibleCollections.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(message: widget.noMatchMessage),
        ),
      ];
    }
    final spacing = context.appSpacing;
    return [
      SliverPadding(
        padding: EdgeInsets.only(
          top: widget.mobile ? spacing.md : 0,
          bottom: widget.mobile ? spacing.md : spacing.lg,
        ),
        sliver: AppAdaptiveCardWrapSliver<T>(
          gridKey: Key('${widget.keyPrefix}-grid'),
          items: visibleCollections,
          orientation: AppCardGridOrientation.landscape,
          itemBuilder: (context, collection, _) => widget.cardBuilder(
            context,
            collection,
            onTap: () => unawaited(widget.onOpen(context, collection)),
            onEdit: () => unawaited(widget.onEdit(context, collection)),
            onDelete: () => unawaited(widget.onDelete(context, collection)),
          ),
        ),
      ),
    ];
  }
}
