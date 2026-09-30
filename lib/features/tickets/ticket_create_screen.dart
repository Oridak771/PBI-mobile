import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/legacy_dialog.dart';
import '../../data/models/ticket.dart';

/// Ticket creation, in the legacy dialog style. Pops the created [Ticket].
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
  late String _type = ticketTypes.containsKey(widget.initialType)
      ? widget.initialType
      : 'other';
  String _priority = 'medium';
  late final _title = TextEditingController(text: widget.initialTitle);
  final _description = TextEditingController();
  String? _titleError;
  String? _descriptionError;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    final description = _description.text.trim();
    setState(() {
      _titleError = title.isEmpty ? 'Titre obligatoire' : null;
      _descriptionError = description.isEmpty ? 'Description obligatoire' : null;
    });
    if (_titleError != null || _descriptionError != null) return;
    setState(() => _busy = true);
    try {
      final ticket = await ref
          .read(repositoryProvider)
          .createTicket(
            NewTicket(
              title: title,
              description: description,
              ticketType: _type,
              priority: _priority,
            ),
          );
      if (!mounted) return;
      showToast(context, 'Demande envoyée');
      Navigator.of(context).pop(ticket);
    } catch (e) {
      if (mounted) showToast(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LegacyDialogScaffold(
    title: 'Nouvelle demande',
    submitLabel: 'Envoyer la demande',
    busy: _busy,
    onSubmit: _submit,
    children: [
      LegacyField(
        label: 'Type',
        child: DropdownButtonFormField<String>(
          initialValue: _type,
          dropdownColor: AppColors.sheet,
          style: legacyFieldTextStyle,
          iconEnabledColor: AppColors.surface,
          decoration: legacyInputDecoration(),
          items: [
            for (final e in ticketTypes.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _type = v ?? _type),
        ),
      ),
      LegacyField(
        label: 'Titre',
        child: TextField(
          controller: _title,
          style: legacyFieldTextStyle,
          decoration: legacyInputDecoration(hint: 'Titre', error: _titleError),
        ),
      ),
      LegacyField(
        label: 'Description',
        child: TextField(
          controller: _description,
          style: legacyFieldTextStyle,
          minLines: 4,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          decoration: legacyInputDecoration(
            hint: 'Description',
            error: _descriptionError,
          ),
        ),
      ),
      LegacyField(
        label: 'Priorité',
        child: DropdownButtonFormField<String>(
          initialValue: _priority,
          dropdownColor: AppColors.sheet,
          style: legacyFieldTextStyle,
          iconEnabledColor: AppColors.surface,
          decoration: legacyInputDecoration(),
          items: [
            for (final e in ticketPriorities.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => _priority = v ?? _priority),
        ),
      ),
    ],
  );
}
