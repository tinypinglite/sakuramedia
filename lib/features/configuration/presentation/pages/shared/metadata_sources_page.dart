import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/configuration/data/dto/metadata_source_dto.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/metadata_sources_api_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/plugin_bindings_section.dart';
import 'package:sakuramedia/features/shared/presentation/restart_messages.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';

class MetadataSourcesPage extends ConsumerStatefulWidget {
  const MetadataSourcesPage({
    super.key,
    required this.active,
    this.mobile = false,
    this.onDirtyChanged,
  });

  final bool active;
  final bool mobile;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  ConsumerState<MetadataSourcesPage> createState() =>
      _MetadataSourcesPageState();
}

class _MetadataSourcesPageState extends ConsumerState<MetadataSourcesPage> {
  bool _initialized = false;
  bool _loading = false;
  bool _saving = false;
  bool _orderDirty = false;
  bool _bindingsDirty = false;
  String? _errorMessage;
  List<MetadataSourceDto> _sources = const <MetadataSourceDto>[];

  AppLocalizations get _l10n => AppLocalizations.of(context);
  bool get _dirty => _orderDirty || _bindingsDirty;

  @override
  void initState() {
    super.initState();
    if (widget.active || widget.mobile) {
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant MetadataSourcesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active && !widget.mobile && _dirty) {
      _initialized = false;
      _orderDirty = false;
      _bindingsDirty = false;
      _sources = const <MetadataSourceDto>[];
    }
    if (widget.active && !_initialized && !_loading) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final sources = await ref.read(metadataSourcesApiProvider).list();
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _loading = false;
        _sources = sources;
        _orderDirty = false;
      });
      widget.onDirtyChanged?.call(_dirty);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _loading = false;
        _errorMessage = apiErrorMessage(
          error,
          fallback: _l10n.metadataSourcesLoadFailed,
          l10n: _l10n,
        );
      });
    }
  }

  Future<void> _refresh() async {
    if (_saving || _loading) {
      return;
    }
    await _load();
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _sources.length) {
      return;
    }
    final next = List<MetadataSourceDto>.of(_sources);
    final item = next.removeAt(index);
    next.insert(target, item);
    setState(() {
      _sources = List<MetadataSourceDto>.unmodifiable(next);
      _orderDirty = true;
    });
    widget.onDirtyChanged?.call(_dirty);
  }

  Future<void> _save() async {
    if (_saving || !_orderDirty) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(metadataSourcesApiProvider)
          .reorder(
            _sources.map((item) => item.pluginId).toList(growable: false),
          );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _orderDirty = false;
      });
      widget.onDirtyChanged?.call(_dirty);
      showToast(
        buildRestartRequiredMessage(_l10n.commonSaved, _l10n),
        tone: AppToastTone.warning,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(
        apiErrorMessage(
          error,
          fallback: _l10n.metadataSourcesSaveFailed,
          l10n: _l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active && !widget.mobile) {
      return const SizedBox.shrink();
    }
    return AppPageRefreshScope(
      onRefresh: _refresh,
      child: widget.mobile
          ? _buildMobileContent(context)
          : _buildContent(context),
    );
  }

  Widget _buildMobileContent(BuildContext context) {
    final spacing = context.appSpacing;
    return ColoredBox(
      key: const Key('mobile-settings-metadata-sources'),
      color: context.appColors.surfaceCard,
      child: AppAdaptiveRefreshScrollView(
        onRefresh: _refresh,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(top: spacing.md, bottom: spacing.lg),
            sliver: SliverToBoxAdapter(child: _buildContent(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final spacing = context.appSpacing;
    if (_loading && !_initialized) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return AppSectionError(
        title: _l10n.metadataSourcesLoadFailed,
        message: _errorMessage!,
        onRetry: _load,
      );
    }
    if (!_initialized) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppNoticeCard(
          leadingIcon: Icons.swap_vert_rounded,
          title: _l10n.metadataSourcesOrderTitle,
          description: _l10n.metadataSourcesOrderDescription,
        ),
        SizedBox(height: spacing.lg),
        AppContentCard(
          key: const Key('metadata-sources-order-card'),
          title: _l10n.metadataSourcesOrderTitle,
          child: _sources.isEmpty
              ? AppEmptyState(
                  key: const Key('metadata-sources-empty-state'),
                  icon: Icons.extension_off_outlined,
                  message: _l10n.metadataSourcesOrderEmpty,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < _sources.length; index++) ...[
                      if (index > 0) SizedBox(height: spacing.sm),
                      _MetadataSourceOrderRow(
                        index: index,
                        source: _sources[index],
                        canMoveUp: index > 0 && !_saving,
                        canMoveDown: index < _sources.length - 1 && !_saving,
                        onMoveUp: () => _move(index, -1),
                        onMoveDown: () => _move(index, 1),
                      ),
                    ],
                    SizedBox(height: spacing.lg),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: AppButton(
                        key: const Key('metadata-sources-save-button'),
                        label: _l10n.metadataSourcesSaveOrder,
                        isLoading: _saving,
                        onPressed: _orderDirty && !_saving
                            ? () => unawaited(_save())
                            : null,
                      ),
                    ),
                  ],
                ),
        ),
        SizedBox(height: spacing.md),
        Text(
          _l10n.metadataSourcesPluginsHint,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        PluginBindingsSection(onDirtyChanged: _handleBindingsDirtyChanged),
      ],
    );
  }

  void _handleBindingsDirtyChanged(bool dirty) {
    if (_bindingsDirty == dirty) {
      return;
    }
    _bindingsDirty = dirty;
    widget.onDirtyChanged?.call(_dirty);
  }
}

class _MetadataSourceOrderRow extends StatelessWidget {
  const _MetadataSourceOrderRow({
    required this.index,
    required this.source,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final MetadataSourceDto source;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final spacing = context.appSpacing;
    return Container(
      key: Key('metadata-source-row-${source.pluginId}'),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          SizedBox(
            width: spacing.xl,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.secondary,
              ),
            ),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Text(
              source.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.medium,
                tone: AppTextTone.primary,
              ),
            ),
          ),
          AppIconButton(
            key: Key('metadata-source-up-${source.pluginId}'),
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            tooltip: l10n.metadataSourcesMoveUp,
            onPressed: canMoveUp ? onMoveUp : null,
          ),
          AppIconButton(
            key: Key('metadata-source-down-${source.pluginId}'),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            tooltip: l10n.metadataSourcesMoveDown,
            onPressed: canMoveDown ? onMoveDown : null,
          ),
        ],
      ),
    );
  }
}
