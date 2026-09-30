import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/ticket.dart';

/// Ticket with its conversation and a message input.
class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final int ticketId;

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  final _input = TextEditingController();
  Ticket? _ticket;
  Object? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final t = await ref.read(repositoryProvider).fetchTicket(widget.ticketId);
      if (mounted) setState(() => _ticket = t);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _send() async {
    final content = _input.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(repositoryProvider).sendTicketMessage(widget.ticketId, content);
      _input.clear();
      await _load();
    } catch (e) {
      if (mounted) showToast(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    Widget body;
    if (ticket == null && _error != null) {
      body = Center(
        child: RetryMessage(message: errorMessage(_error!), onRetry: _load),
      );
    } else if (ticket == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final statusColor = ticket.isActive ? AppColors.blue : AppColors.greyText;
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(10),
          children: [
            Text(
              ticket.title,
              style: const TextStyle(
                color: AppColors.gray,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${ticket.ticketTypeLabel} · '
              '${ticket.statusLabel.isEmpty ? ticket.status : ticket.statusLabel}'
              ' · ${formatDate(ticket.createdAt)}',
              style: TextStyle(color: statusColor),
            ),
            if (ticket.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                ticket.description,
                style: const TextStyle(color: AppColors.tint, fontSize: 15),
              ),
            ],
            const SizedBox(height: 10),
            for (final m in ticket.messages) MessageBubble(message: m),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(title: 'Demande #${widget.ticketId}'),
            Expanded(child: body),
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(color: AppColors.gray),
                      decoration: const InputDecoration(
                        hintText: 'Votre message',
                        hintStyle: TextStyle(color: AppColors.greyText),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Envoyer',
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send, color: AppColors.blueGreen),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat bubble: mine on the right (`#358BA4`), others on the left.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final TicketMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: mine ? AppColors.blueGreen : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 2),
              bottomRight: Radius.circular(mine ? 2 : 14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine && message.sender.isNotEmpty)
                Text(
                  message.sender,
                  style: const TextStyle(
                    color: AppColors.greyText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Text(
                message.content,
                style: const TextStyle(color: AppColors.gray, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                '${formatDate(message.createdAt)} ${formatTime(message.createdAt)}',
                style: const TextStyle(color: AppColors.tint, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
