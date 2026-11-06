import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/actor_search_selection_controller.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_picker_results.dart';

class ActorMergeResult {
  const ActorMergeResult({required this.actor, required this.sourceActorIds});

  final ActorDetailDto actor;
  final List<int> sourceActorIds;
}

Future<ActorMergeResult?> showActorMergeDialog(
  BuildContext context, {
  required ActorDetailDto actor,
  required ActorsApi api,
}) {
  return showAppAdaptiveModal<ActorMergeResult>(
    context: context,
    modalKey: const Key('actor-merge-dialog'),
    desktopWidth: context.appLayoutTokens.dialogWidthMd,
    builder: (_) => ActorMergeDialog(actor: actor, api: api),
  );
}

class ActorMergeDialog extends StatefulWidget {
  const ActorMergeDialog({super.key, required this.actor, required this.api});

  final ActorDetailDto actor;
  final ActorsApi api;

  @override
  State<ActorMergeDialog> createState() => _ActorMergeDialogState();
}

class _ActorMergeDialogState extends State<ActorMergeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final ActorSearchSelectionController _search;

  bool _isSubmitting = false;
  String? _submitErrorMessage;

  int get _targetActorId => widget.actor.summary.id;

  @override
  void initState() {
    super.initState();
    _search = ActorSearchSelectionController(
      api: widget.api,
      l10n: () => AppLocalizations.of(context),
      searchFailedMessage: (l10n) => l10n.actorMergeSearchFailed,
      excludedActorIds: <int>{_targetActorId},
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || _search.selectedCount == 0) return;
    final sourceActorIds = _search.selectedIds;
    setState(() {
      _isSubmitting = true;
      _submitErrorMessage = null;
    });
    try {
      final merged = await widget.api.mergeActors(
        actorId: _targetActorId,
        sourceActorIds: sourceActorIds,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(ActorMergeResult(actor: merged, sourceActorIds: sourceActorIds));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitErrorMessage = apiErrorMessage(
          error,
          fallback: AppLocalizations.of(context).actorMergeFailed,
          l10n: AppLocalizations.of(context),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _search,
      builder: (context, _) {
        final selectedCount = _search.selectedCount;
        return AppBottomFormSheet(
          key: const Key('actor-merge-form'),
          formKey: _formKey,
          title: l10n.actorMergeTitle,
          subtitle: l10n.actorMergeSubtitle,
          submitKey: const Key('actor-merge-confirm-button'),
          submitLabel: selectedCount == 0
              ? l10n.actorMergeSubmitLabel
              : l10n.actorMergeSubmitLabelWithCount(selectedCount),
          isSubmitting: _isSubmitting,
          submitDisabled: selectedCount == 0,
          onSubmit: () => unawaited(_submit()),
          body: _buildBody(context),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActorPickerResults.actorMerge(controller: _search),
        if (_submitErrorMessage != null) ...[
          SizedBox(height: spacing.sm),
          Text(
            _submitErrorMessage!,
            key: const Key('actor-merge-error'),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.error,
            ),
          ),
        ],
      ],
    );
  }
}
