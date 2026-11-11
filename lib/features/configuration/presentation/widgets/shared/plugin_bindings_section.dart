import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/plugins/data/dto/plugin_binding_dto.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_bindings_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/restart_messages.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_section_error.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/forms/app_select_field.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';

class PluginBindingsSection extends ConsumerWidget {
  const PluginBindingsSection({super.key, this.onDirtyChanged});

  final ValueChanged<bool>? onDirtyChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bindings = ref.watch(pluginBindingsProvider);
    return bindings.when(
      loading: () => const AppSkeletonizer(
        child: _PluginBindingsForm(data: PluginBindingsDto(), loading: true),
      ),
      error: (_, _) => AppSectionError(
        title: AppLocalizations.of(context).pluginBindingsTitle,
        message: AppLocalizations.of(context).pluginBindingsLoadFailed,
        onRetry: () async {
          ref.invalidate(pluginBindingsProvider);
        },
      ),
      data: (data) => _PluginBindingsForm(
        key: ValueKey(
          '${data.statsSource}-${data.reviewSource}-'
          '${data.availableStatsSources.length}-'
          '${data.availableReviewSources.length}',
        ),
        data: data,
        onDirtyChanged: onDirtyChanged,
      ),
    );
  }
}

class _PluginBindingsForm extends ConsumerStatefulWidget {
  const _PluginBindingsForm({
    super.key,
    required this.data,
    this.onDirtyChanged,
    this.loading = false,
  });

  final PluginBindingsDto data;
  final ValueChanged<bool>? onDirtyChanged;
  final bool loading;

  @override
  ConsumerState<_PluginBindingsForm> createState() =>
      _PluginBindingsFormState();
}

class _PluginBindingsFormState extends ConsumerState<_PluginBindingsForm> {
  late String? _statsSource;
  late String? _reviewSource;
  bool _saving = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _statsSource = widget.data.statsSource;
    _reviewSource = widget.data.reviewSource;
  }

  bool get _dirty =>
      _statsSource != widget.data.statsSource ||
      _reviewSource != widget.data.reviewSource;

  Future<void> _save() async {
    if (_saving || !_dirty) {
      return;
    }
    setState(() => _saving = true);
    try {
      final statsSource = _availableSourceId(
        _statsSource,
        widget.data.availableStatsSources,
      );
      final reviewSource = _availableSourceId(
        _reviewSource,
        widget.data.availableReviewSources,
      );
      await ref
          .read(pluginsApiProvider)
          .updateBindings(statsSource: statsSource, reviewSource: reviewSource);
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      widget.onDirtyChanged?.call(false);
      ref.invalidate(pluginBindingsProvider);
      showToast(
        buildRestartRequiredMessage(_l10n.pluginBindingsSave, _l10n),
        tone: AppToastTone.warning,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      showToast(
        apiErrorMessage(
          error,
          fallback: _l10n.pluginBindingsSaveFailed,
          l10n: _l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  void _setStatsSource(String? value) {
    setState(() => _statsSource = value);
    widget.onDirtyChanged?.call(_dirty);
  }

  void _setReviewSource(String? value) {
    setState(() => _reviewSource = value);
    widget.onDirtyChanged?.call(_dirty);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final statsSources = widget.data.availableStatsSources;
    final reviewSources = widget.data.availableReviewSources;
    final unavailableBindings = <String>[
      if (widget.data.statsSource != null && !widget.data.statsSourceAvailable)
        _l10n.pluginBindingsSourceUnavailable(
          widget.data.statsSourceDisplayName ?? widget.data.statsSource!,
        ),
      if (widget.data.reviewSource != null &&
          !widget.data.reviewSourceAvailable)
        _l10n.pluginBindingsSourceUnavailable(
          widget.data.reviewSourceDisplayName ?? widget.data.reviewSource!,
        ),
    ];
    return AppContentCard(
      key: const Key('plugin-bindings-card'),
      title: _l10n.pluginBindingsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppNoticeCard(
            leadingIcon: Icons.hub_outlined,
            title: _l10n.pluginBindingsTitle,
            description: _l10n.pluginBindingsDescription,
          ),
          SizedBox(height: spacing.lg),
          for (final message in unavailableBindings) ...[
            Text(
              message,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.error,
              ),
            ),
            SizedBox(height: spacing.md),
          ],
          if (statsSources.isEmpty && reviewSources.isEmpty)
            AppEmptyState(
              key: const Key('plugin-bindings-empty-state'),
              icon: Icons.extension_off_outlined,
              message: _l10n.pluginBindingsEmpty,
            )
          else ...[
            if (statsSources.isEmpty)
              Text(
                _l10n.pluginBindingsNoStatsSource,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.secondary,
                ),
              )
            else
              AppSelectField<String?>(
                key: const Key('plugin-bindings-stats-select'),
                label: _l10n.pluginBindingsStatsLabel,
                value: _statsSource,
                onChanged: widget.loading ? null : _setStatsSource,
                items: _bindingItems(
                  unboundLabel: _l10n.pluginBindingsUnbound,
                  sources: statsSources,
                ),
              ),
            SizedBox(height: spacing.md),
            if (reviewSources.isEmpty)
              Text(
                _l10n.pluginBindingsNoReviewSource,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  tone: AppTextTone.secondary,
                ),
              )
            else
              AppSelectField<String?>(
                key: const Key('plugin-bindings-review-select'),
                label: _l10n.pluginBindingsReviewLabel,
                value: _reviewSource,
                onChanged: widget.loading ? null : _setReviewSource,
                items: _bindingItems(
                  unboundLabel: _l10n.pluginBindingsUnbound,
                  sources: reviewSources,
                ),
              ),
            SizedBox(height: spacing.lg),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppButton(
                key: const Key('plugin-bindings-save-button'),
                label: _l10n.pluginBindingsSave,
                isLoading: _saving,
                onPressed: _dirty && !widget.loading && !_saving
                    ? () => unawaited(_save())
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<DropdownMenuItem<String?>> _bindingItems({
    required String unboundLabel,
    required List<PluginBindingSourceDto> sources,
  }) {
    return <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(value: null, child: Text(unboundLabel)),
      for (final source in sources)
        DropdownMenuItem<String?>(
          value: source.pluginId,
          child: Text(source.displayName),
        ),
    ];
  }

  String? _availableSourceId(
    String? value,
    List<PluginBindingSourceDto> sources,
  ) {
    if (value == null) {
      return null;
    }
    return sources.any((source) => source.pluginId == value) ? value : null;
  }
}
