import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/layout/adaptive.dart';
import '../../core/providers.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/ticket.dart';
import 'attachment_picker.dart';
import 'ticket_create_screen.dart';
import 'ticket_widgets.dart';
import 'tickets_controller.dart';

/// Full-screen ticket (phones / medium windows).
class TicketDetailScreen extends StatelessWidget {
  const TicketDetailScreen({super.key, required this.ticketId, this.onChanged});

  final int ticketId;

  /// Called after a message or an admin change (to refresh the list).
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          ScreenHeader(title: 'Ticket #$ticketId'),
          Expanded(
            child: TicketDetailView(ticketId: ticketId, onChanged: onChanged),
          ),
        ],
      ),
    ),
  );
}

/// Ticket header, admin panel (when `can_manage`), conversation and the
/// message composer. Used full screen and as the right pane on tablets.
class TicketDetailView extends ConsumerStatefulWidget {
  const TicketDetailView({super.key, required this.ticketId, this.onChanged});

  final int ticketId;
  final VoidCallback? onChanged;

  @override
  ConsumerState<TicketDetailView> createState() => _TicketDetailViewState();
}

class _TicketDetailViewState extends ConsumerState<TicketDetailView> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Ticket? _ticket;
  Object? _error;
  bool _sending = false;
  TicketAttachment? _pending;
  String? _composerError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TicketDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticketId != widget.ticketId) {
      _ticket = null;
      _pending = null;
      _composerError = null;
      _input.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.ticketId;
    setState(() => _error = null);
    try {
      final t = await ref.read(repositoryProvider).fetchTicket(id);
      if (mounted && id == widget.ticketId) setState(() => _ticket = t);
    } catch (e) {
      if (mounted && id == widget.ticketId) setState(() => _error = e);
    }
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _attach() async {
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
    setState(() {
      if (picked!.length > max) {
        _composerError = attachmentTooLarge(picked.length, max);
      } else {
        _pending = picked;
        _composerError = null;
      }
    });
  }

  Future<void> _send() async {
    final content = _input.text.trim();
    if (_sending) return;
    if (content.isEmpty) {
      if (_pending != null) {
        setState(() => _composerError = 'Ajoutez un message avec l’image.');
      }
      return;
    }
    setState(() {
      _sending = true;
      _composerError = null;
    });
    final id = widget.ticketId;
    try {
      final message = await ref
          .read(repositoryProvider)
          .sendTicketMessage(id, content, attachment: _pending);
      if (!mounted || id != widget.ticketId) return;
      _input.clear();
      setState(() {
        _pending = null;
        final t = _ticket;
        if (t != null) {
          _ticket = t.copyWith(
            messages: [...t.messages, message],
            messagesCount: t.messages.length + 1,
          );
        }
      });
      _scrollToEnd();
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      final mapped = mapServerErrors(
        e,
        fields: const {'content', 'attachment'},
      );
      final fieldMessage = mapped.fields.values.firstOrNull;
      setState(() => _composerError = fieldMessage);
      if (mapped.message != null) showToast(context, mapped.message!);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Admin change, applied at once and rolled back if the server refuses it.
  Future<void> _update(TicketUpdate update, Ticket optimistic) async {
    final previous = _ticket;
    if (previous == null) return;
    setState(() => _ticket = optimistic);
    try {
      final saved = await ref
          .read(repositoryProvider)
          .updateTicket(widget.ticketId, update);
      if (!mounted) return;
      setState(() => _ticket = (_ticket ?? previous).mergeUpdate(saved));
      showToast(context, 'Ticket mis à jour');
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _ticket = previous);
      showToast(context, errorMessage(e));
    }
  }

  void _changeStatus(String status) {
    final t = _ticket;
    if (t == null || t.status == status) return;
    final label = TicketChoices.labelOf(
      ref.read(currentTicketChoicesProvider).statuses,
      status,
    );
    _update(
      TicketUpdate.status(status),
      t.copyWith(status: status, statusLabel: label),
    );
  }

  void _changeAssignee(TicketPerson? person) {
    final t = _ticket;
    if (t == null || t.assignedTo?.id == person?.id) return;
    _update(
      TicketUpdate.assignee(person?.id),
      t.copyWith(assignedTo: () => person),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    if (ticket == null) {
      if (_error != null) {
        return Center(
          child: SingleChildScrollView(
            child: RetryMessage(message: errorMessage(_error!), onRetry: _load),
          ),
        );
      }
      return const SkeletonList(count: 4, lines: 3);
    }
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: CenteredContent(
              builder: (context, gutter) => ListView(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 16),
                children: [
                  TicketHeaderCard(ticket: ticket),
                  if (ticket.canManage) ...[
                    const SizedBox(height: 12),
                    TicketAdminPanel(
                      ticket: ticket,
                      onStatus: _changeStatus,
                      onAssignee: _changeAssignee,
                    ),
                  ],
                  SectionHeader(
                    'Conversation',
                    count: ticket.messages.length,
                    padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
                  ),
                  if (ticket.messages.isEmpty)
                    const EmptyText(
                      'Aucun message pour le moment',
                      padding: 16,
                      icon: Icons.forum_outlined,
                    ),
                  for (final m in ticket.messages)
                    MessageBubble(key: ValueKey('message-${m.id}'), message: m),
                ],
              ),
            ),
          ),
        ),
        TicketComposer(
          controller: _input,
          sending: _sending,
          pending: _pending,
          error: _composerError,
          onAttach: _attach,
          onRemoveAttachment: () => setState(() {
            _pending = null;
            _composerError = null;
          }),
          onSend: _send,
        ),
      ],
    );
  }
}

/// Title, status, type / category / priority, people, dates, description
/// and the attachment.
class TicketHeaderCard extends StatelessWidget {
  const TicketHeaderCard({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final created = ticket.createdAt;
    final updated = ticket.updatedAt;
    final attachment = ticket.attachmentUrl;
    return AppCard(
      key: const Key('ticket-header'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ticket.title,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: TicketStatusPill.of(ticket),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetaRow(
            label: 'Type',
            child: _metaText(context, ticket.ticketTypeLabel),
          ),
          _MetaRow(
            label: 'Catégorie',
            child: _metaText(context, ticket.categoryLabel),
          ),
          _MetaRow(
            label: 'Priorité',
            child: TicketPriority(
              priority: ticket.priority,
              label: ticket.priorityLabel,
              fontSize: 13.5,
            ),
          ),
          _MetaRow(
            label: 'Créé par',
            child: _person(context, ticket.createdBy),
          ),
          _MetaRow(
            label: 'Assigné à',
            child: _person(context, ticket.assignedTo),
          ),
          if (created != null)
            _MetaRow(
              label: 'Créé le',
              child: _metaText(
                context,
                '${formatDate(created)} ${formatTime(created)}',
              ),
            ),
          if (updated != null)
            _MetaRow(
              label: 'Mis à jour',
              child: _metaText(
                context,
                '${formatDate(updated)} ${formatTime(updated)}',
              ),
            ),
          if (ticket.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(color: palette.border, height: 1),
            const SizedBox(height: 10),
            SelectableText(
              ticket.description,
              style: TextStyle(color: palette.text, fontSize: 15, height: 1.4),
            ),
          ],
          if (attachment != null) ...[
            const SizedBox(height: 12),
            TicketImageThumb(url: attachment, width: 200, height: 140),
          ],
        ],
      ),
    );
  }

  static Widget _metaText(BuildContext context, String text) =>
      Text(text, style: TextStyle(color: context.palette.text, fontSize: 13.5));

  static Widget _person(BuildContext context, TicketPerson? person) {
    if (person == null) {
      return Text(
        'Non assigné',
        style: TextStyle(color: context.palette.textSubtle, fontSize: 13.5),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PersonAvatar(person: person, size: 20),
        const SizedBox(width: 6),
        Flexible(child: _metaText(context, person.name)),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(color: context.palette.textMuted, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      ],
    ),
  );
}

/// Admins (`can_manage`): status and assignee, saved at once.
class TicketAdminPanel extends ConsumerWidget {
  const TicketAdminPanel({
    super.key,
    required this.ticket,
    required this.onStatus,
    required this.onAssignee,
  });

  final Ticket ticket;
  final ValueChanged<String> onStatus;
  final ValueChanged<TicketPerson?> onAssignee;

  /// "Non assigné" entry of the assignee dropdown (ids are positive).
  static const _unassigned = 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final choices = ref.watch(currentTicketChoicesProvider);
    final admins =
        ref.watch(ticketAdminsProvider).value ?? const <TicketPerson>[];
    final current = ticket.assignedTo;
    final people = [
      ...admins,
      if (current != null && !admins.any((a) => a.id == current.id)) current,
    ];
    final statuses = [
      ...choices.statuses,
      if (!TicketChoices.contains(choices.statuses, ticket.status))
        TicketChoice(ticket.status, ticket.statusLabel),
    ];
    final narrow = MediaQuery.sizeOf(context).width < 420;

    final status = _Labeled(
      label: 'Statut',
      child: DropdownButtonFormField<String>(
        key: ValueKey('admin-status-${ticket.status}'),
        initialValue: ticket.status,
        isExpanded: true,
        borderRadius: BorderRadius.circular(AppDimens.radiusControl),
        items: [
          for (final s in statuses)
            DropdownMenuItem(
              value: s.value,
              child: Text(
                s.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) {
          if (v != null) onStatus(v);
        },
      ),
    );
    final assignee = _Labeled(
      label: 'Assigné à',
      child: DropdownButtonFormField<int>(
        key: ValueKey('admin-assignee-${current?.id}-${people.length}'),
        initialValue: current?.id ?? _unassigned,
        isExpanded: true,
        borderRadius: BorderRadius.circular(AppDimens.radiusControl),
        items: [
          const DropdownMenuItem(
            value: _unassigned,
            child: Text(
              'Non assigné',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final p in people)
            DropdownMenuItem(
              value: p.id,
              child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (id) {
          if (id == null) return;
          onAssignee(
            id == _unassigned
                ? null
                : people.where((p) => p.id == id).firstOrNull,
          );
        },
      ),
    );

    return AppCard(
      key: const Key('ticket-admin-panel'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 18,
                color: palette.primaryText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Gestion du ticket',
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (narrow) ...[
            status,
            const SizedBox(height: 10),
            assignee,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: status),
                const SizedBox(width: 12),
                Expanded(child: assignee),
              ],
            ),
        ],
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: Text(
          label,
          style: TextStyle(
            color: context.palette.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child,
    ],
  );
}

/// Chat bubble: mine on the right (primary tint), others on the left
/// (surfaceAlt) with the author and an "Admin BI" badge.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final TicketMessage message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final mine = message.isMine;
    final attachment = message.attachmentUrl;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (context, constraints) => ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.82),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 7),
            decoration: BoxDecoration(
              color: mine
                  ? palette.primary.withValues(alpha: 0.16)
                  : palette.surfaceAlt,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(mine ? 14 : 4),
                bottomRight: Radius.circular(mine ? 4 : 14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!mine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          message.authorName,
                          style: TextStyle(
                            color: palette.primaryText,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (message.fromAdmin) const AdminBadge(),
                      ],
                    ),
                  ),
                if (message.content.isNotEmpty)
                  SelectableText(
                    message.content,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                if (attachment != null) ...[
                  const SizedBox(height: 6),
                  TicketImageThumb(url: attachment, width: 180, height: 130),
                ],
                const SizedBox(height: 3),
                Text(
                  '${formatDate(message.createdAt)} ${formatTime(message.createdAt)}',
                  style: TextStyle(color: palette.textSubtle, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom composer: attach image, text, send. Stays above the keyboard (the
/// Scaffold resizes).
class TicketComposer extends StatelessWidget {
  const TicketComposer({
    super.key,
    required this.controller,
    required this.sending,
    required this.onAttach,
    required this.onRemoveAttachment,
    required this.onSend,
    this.pending,
    this.error,
  });

  final TextEditingController controller;
  final bool sending;
  final TicketAttachment? pending;
  final String? error;
  final VoidCallback onAttach;
  final VoidCallback onRemoveAttachment;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final file = pending;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: ContentWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (file != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                    child: AttachmentPreview(
                      attachment: file,
                      onRemove: onRemoveAttachment,
                      thumb: 48,
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                    child: Text(
                      error!,
                      key: const Key('composer-error'),
                      style: TextStyle(color: palette.danger, fontSize: 12.5),
                    ),
                  ),
                Row(
                  children: [
                    IconButton(
                      key: const Key('composer-attach'),
                      tooltip: 'Joindre une image',
                      onPressed: sending ? null : onAttach,
                      icon: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: palette.textMuted,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        key: const Key('composer-input'),
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Votre message',
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filled(
                      key: const Key('composer-send'),
                      tooltip: 'Envoyer',
                      onPressed: sending ? null : onSend,
                      style: IconButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.onPrimary,
                      ),
                      icon: sending
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: palette.onPrimary,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
