import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_page.dart';
import '../../data/models/ticket.dart';
import 'attachment_picker.dart';
import 'tickets_controller.dart';

/// "Nouveau ticket": the web `TicketForm` (title, description, type,
/// category, priority, optional image). Pops the created [Ticket].
class TicketCreateScreen extends ConsumerStatefulWidget {
  const TicketCreateScreen({
    super.key,
    this.initialType = 'other',
    this.initialTitle = '',
  });

  final String initialType;
  final String initialTitle;

  @override
  ConsumerState<TicketCreateScreen> createState() => _TicketCreateScreenState();
}

class _TicketCreateScreenState extends ConsumerState<TicketCreateScreen> {
  late final _title = TextEditingController(text: widget.initialTitle);
  final _description = TextEditingController();
  String? _type;
  String _category = 'cbi';
  String _priority = 'medium';
  TicketAttachment? _attachment;

  /// Field (server name) → message: client validation or server `errors`.
  Map<String, String> _errors = const {};
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  String _typeOf(TicketChoices choices) {
    final type = _type ?? widget.initialType;
    if (TicketChoices.contains(choices.ticketTypes, type)) return type;
    if (TicketChoices.contains(choices.ticketTypes, 'other')) return 'other';
    return choices.ticketTypes.first.value;
  }

  void _clearError(String field) {
    if (!_errors.containsKey(field)) return;
    setState(() => _errors = {..._errors}..remove(field));
  }

  Future<void> _pick() async {
    final source = await chooseAttachmentSource(context);
    if (source == null || !mounted) return;
    final max = ref.read(currentTicketChoicesProvider).maxAttachmentBytes;
    TicketAttachment? picked;
    try {
      picked = await ref.read(ticketImagePickerProvider).pick(source);
    } catch (_) {
      if (mounted) showToast(context, "Impossible d'ouvrir l'image.");
      return;
    }
    if (picked == null || !mounted) return;
    if (picked.length > max) {
      // Rejected before upload: the server would refuse it anyway.
      setState(
        () => _errors = {
          ..._errors,
          TicketFields.attachment: attachmentTooLarge(picked!.length, max),
        },
      );
      return;
    }
    setState(() {
      _attachment = picked;
      _errors = {..._errors}..remove(TicketFields.attachment);
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final choices = ref.read(currentTicketChoicesProvider);
    final type = _typeOf(choices);
    final errors = validateTicketForm(
      title: _title.text,
      description: _description.text,
      ticketType: type,
      category: _category,
      priority: _priority,
      choices: choices,
      attachment: _attachment,
    );
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final ticket = await ref
          .read(repositoryProvider)
          .createTicket(
            NewTicket(
              title: _title.text.trim(),
              description: _description.text.trim(),
              ticketType: type,
              category: _category,
              priority: _priority,
              attachment: _attachment,
            ),
          );
      if (!mounted) return;
      showToast(context, 'Ticket envoyé');
      Navigator.of(context).pop(ticket);
    } catch (e) {
      if (!mounted) return;
      final mapped = mapServerErrors(e);
      setState(() => _errors = mapped.fields);
      final message = mapped.message;
      if (message != null) showToast(context, message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final choices = ref.watch(currentTicketChoicesProvider);
    final type = _typeOf(choices);
    final category = TicketChoices.contains(choices.categories, _category)
        ? _category
        : choices.categories.first.value;
    final priority = TicketChoices.contains(choices.priorities, _priority)
        ? _priority
        : choices.priorities.first.value;
    return FormPageScaffold(
      title: 'Nouveau ticket',
      submitLabel: 'Envoyer le ticket',
      busy: _busy,
      onSubmit: _submit,
      children: [
        LabeledField(
          label: 'Titre',
          child: TextField(
            key: const Key('ticket-title'),
            controller: _title,
            maxLength: TicketFields.titleMaxLength,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _clearError(TicketFields.title),
            decoration: InputDecoration(
              hintText: 'Titre du ticket',
              counterText: '',
              errorText: _errors[TicketFields.title],
              errorMaxLines: 3,
            ),
          ),
        ),
        LabeledField(
          label: 'Description',
          child: TextField(
            key: const Key('ticket-description'),
            controller: _description,
            minLines: 4,
            maxLines: 10,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _clearError(TicketFields.description),
            decoration: InputDecoration(
              hintText: 'Décrivez votre demande',
              errorText: _errors[TicketFields.description],
              errorMaxLines: 3,
            ),
          ),
        ),
        _ChoiceField(
          fieldKey: const Key('ticket-type'),
          label: 'Type',
          value: type,
          choices: choices.ticketTypes,
          error: _errors[TicketFields.ticketType],
          onChanged: (v) {
            setState(() => _type = v);
            _clearError(TicketFields.ticketType);
          },
        ),
        _ChoiceField(
          fieldKey: const Key('ticket-category'),
          label: 'Catégorie',
          value: category,
          choices: choices.categories,
          error: _errors[TicketFields.category],
          onChanged: (v) {
            setState(() => _category = v);
            _clearError(TicketFields.category);
          },
        ),
        _ChoiceField(
          fieldKey: const Key('ticket-priority'),
          label: 'Priorité',
          value: priority,
          choices: choices.priorities,
          error: _errors[TicketFields.priority],
          onChanged: (v) {
            setState(() => _priority = v);
            _clearError(TicketFields.priority);
          },
        ),
        LabeledField(
          label: 'Pièce jointe (image, facultatif)',
          child: AttachmentField(
            attachment: _attachment,
            error: _errors[TicketFields.attachment],
            onPick: _busy ? null : _pick,
            onRemove: () => setState(() {
              _attachment = null;
              _errors = {..._errors}..remove(TicketFields.attachment);
            }),
          ),
        ),
      ],
    );
  }
}

class _ChoiceField extends StatelessWidget {
  const _ChoiceField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.choices,
    required this.onChanged,
    this.error,
  });

  final Key fieldKey;
  final String label;
  final String value;
  final List<TicketChoice> choices;
  final String? error;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => LabeledField(
    label: label,
    child: KeyedSubtree(
      key: fieldKey,
      child: DropdownButtonFormField<String>(
        // Rebuilt when the choices arrive from the server.
        key: ValueKey('$value-${choices.length}'),
        initialValue: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(AppDimens.radiusControl),
        dropdownColor: context.palette.sheet,
        style: TextStyle(color: context.palette.text, fontSize: 14.5),
        decoration: InputDecoration(errorText: error, errorMaxLines: 3),
        items: [
          for (final c in choices)
            DropdownMenuItem(
              value: c.value,
              child: Text(
                c.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    ),
  );
}

/// Optional image: "Ajouter une image" button, or the preview with a remove
/// button; the size / server error underneath.
class AttachmentField extends StatelessWidget {
  const AttachmentField({
    super.key,
    required this.attachment,
    required this.onPick,
    required this.onRemove,
    this.error,
  });

  final TicketAttachment? attachment;
  final VoidCallback? onPick;
  final VoidCallback onRemove;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final file = attachment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (file == null)
          OutlinedButton.icon(
            key: const Key('ticket-attach'),
            onPressed: onPick,
            icon: Icon(
              Icons.add_photo_alternate_outlined,
              color: palette.primaryText,
            ),
            label: const Text('Ajouter une image'),
          )
        else
          AttachmentPreview(attachment: file, onRemove: onRemove),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              error!,
              key: const Key('ticket-attachment-error'),
              style: TextStyle(color: palette.danger, fontSize: 12.5),
            ),
          ),
      ],
    );
  }
}

/// Picked image (before upload): thumbnail, name, size, remove "X".
class AttachmentPreview extends StatelessWidget {
  const AttachmentPreview({
    super.key,
    required this.attachment,
    required this.onRemove,
    this.thumb = 72,
  });

  final TicketAttachment attachment;
  final VoidCallback onRemove;
  final double thumb;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      key: const Key('attachment-preview'),
      padding: const EdgeInsets.all(8),
      color: palette.surfaceAlt,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              attachment.bytes,
              width: thumb,
              height: thumb,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: thumb,
                height: thumb,
                color: palette.border,
                alignment: Alignment.center,
                child: Icon(Icons.image_outlined, color: palette.textSubtle),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.text, fontSize: 14),
                ),
                Text(
                  formatBytesFr(attachment.length),
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('attachment-remove'),
            tooltip: "Retirer l'image",
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded, color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}
