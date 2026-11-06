import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/actor_search_selection_controller.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/navigation/app_back_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_form_sheet.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_dismiss_controller.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_picker_results.dart';

/// 影片演员表的添加弹层：搜索女优库、多选，或原地新建本地女优。
///
/// 返回值只包含用户选中的演员；真正写入影片关联由调用方统一处理。
Future<List<ActorListItemDto>?> showMovieActorPickerSheet(
  BuildContext context, {
  required ActorsApi actorsApi,
  required Set<int> existingActorIds,
}) async {
  final dismissController = AppModalDismissController();
  try {
    return await showAppAdaptiveModal<List<ActorListItemDto>>(
      context: context,
      modalKey: const Key('movie-actor-picker'),
      desktopWidth: context.appLayoutTokens.dialogWidthMd,
      dismissController: dismissController,
      builder: (_) => MovieActorPickerSheet(
        actorsApi: actorsApi,
        existingActorIds: existingActorIds,
        dismissController: dismissController,
      ),
    );
  } finally {
    dismissController.dispose();
  }
}

enum _PickerMode { pick, create }

class MovieActorPickerSheet extends StatefulWidget {
  const MovieActorPickerSheet({
    super.key,
    required this.actorsApi,
    required this.existingActorIds,
    this.dismissController,
  });

  final ActorsApi actorsApi;
  final Set<int> existingActorIds;
  final AppModalDismissController? dismissController;

  @override
  State<MovieActorPickerSheet> createState() => _MovieActorPickerSheetState();
}

class _MovieActorPickerSheetState extends State<MovieActorPickerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _createNameController = TextEditingController();
  final _createAliasController = TextEditingController();
  late final ActorSearchSelectionController _search;

  _PickerMode _mode = _PickerMode.pick;
  bool _isCreating = false;
  String? _createErrorMessage;

  @override
  void initState() {
    super.initState();
    _search = ActorSearchSelectionController(
      api: widget.actorsApi,
      l10n: () => AppLocalizations.of(context),
      searchFailedMessage: (l10n) => l10n.movieWidgetActorSearchFailed,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _createNameController.dispose();
    _createAliasController.dispose();
    super.dispose();
  }

  void _enterCreate([String? query]) {
    final seed = (query ?? _search.query).trim();
    _createNameController.text = seed;
    _createAliasController.clear();
    setState(() {
      _mode = _PickerMode.create;
      _createErrorMessage = null;
    });
  }

  void _backToPick() {
    setState(() {
      _mode = _PickerMode.pick;
      _createErrorMessage = null;
    });
  }

  void _submitPick() {
    if (_search.selectedCount == 0) return;
    Navigator.of(context).pop(_search.selectedActors);
  }

  Future<void> _submitCreate() async {
    if (_isCreating) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isCreating = true;
      _createErrorMessage = null;
    });
    try {
      final created = await widget.actorsApi.createLocalActor(
        name: _createNameController.text,
        aliasName: _createAliasController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(<ActorListItemDto>[created.summary]);
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _isCreating = false;
        _createErrorMessage = apiErrorMessage(
          error,
          fallback: l10n.movieWidgetLocalActorCreateFailed,
          l10n: l10n,
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
        final isCreate = _mode == _PickerMode.create;
        final selectedCount = _search.selectedCount;
        return AppBottomFormSheet(
          key: const Key('movie-actor-picker-form'),
          formKey: _formKey,
          title: isCreate
              ? l10n.movieWidgetCreateLocalActorTitle
              : l10n.movieWidgetAddActorTitle,
          subtitle: isCreate
              ? l10n.movieWidgetCreateLocalActorSubtitle
              : l10n.movieWidgetActorPickerSubtitle,
          submitKey: Key(
            isCreate
                ? 'movie-actor-create-confirm'
                : 'movie-actor-picker-confirm',
          ),
          submitLabel: isCreate
              ? l10n.movieWidgetCreateAndAdd
              : (selectedCount == 0
                    ? l10n.movieWidgetAddActorTitle
                    : l10n.movieWidgetAddActorsCount(selectedCount)),
          isSubmitting: _isCreating,
          dismissController: widget.dismissController,
          submitDisabled: !isCreate && selectedCount == 0,
          onSubmit: () {
            if (isCreate) {
              unawaited(_submitCreate());
            } else {
              _submitPick();
            }
          },
          body: isCreate
              ? _buildCreateBody(context, l10n)
              : ActorPickerResults.movieCast(
                  controller: _search,
                  existingActorIds: widget.existingActorIds,
                  onCreateLocalActor: _enterCreate,
                ),
        );
      },
    );
  }

  Widget _buildCreateBody(BuildContext context, AppLocalizations l10n) {
    final spacing = context.appSpacing;
    return SizedBox(
      height: actorPickerBodyHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppTextButton(
              key: const Key('movie-actor-create-back'),
              label: l10n.movieWidgetBackToSelection,
              icon: Icon(
                AppBackButton.icon,
                size: context.appComponentTokens.iconSizeXs,
              ),
              size: AppTextButtonSize.xSmall,
              onPressed: _isCreating ? null : _backToPick,
            ),
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('movie-actor-create-name-field'),
            controller: _createNameController,
            label: l10n.movieWidgetActorNameLabel,
            hintText: l10n.movieWidgetActorNameRequired,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              final name = value?.trim() ?? '';
              if (name.isEmpty) return l10n.movieWidgetActorNameRequired;
              if (name.length > 255) return l10n.movieWidgetActorNameTooLong;
              return null;
            },
          ),
          SizedBox(height: spacing.md),
          AppTextField(
            fieldKey: const Key('movie-actor-create-alias-field'),
            controller: _createAliasController,
            label: l10n.movieWidgetActorAliasLabel,
            hintText: l10n.movieWidgetActorAliasHint,
            helperText: l10n.movieWidgetActorAliasHelper,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              final alias = value?.trim() ?? '';
              if (alias.length > 1024) return l10n.movieWidgetActorAliasTooLong;
              return null;
            },
          ),
          if (_createErrorMessage != null) ...[
            SizedBox(height: spacing.sm),
            Text(
              _createErrorMessage!,
              key: const Key('movie-actor-create-error'),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
