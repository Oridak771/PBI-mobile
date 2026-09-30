import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/ticket.dart';
import 'ticket_create_screen.dart';
import 'ticket_detail_screen.dart';

final ticketsProvider = FutureProvider.autoDispose<List<Ticket>>(
  (ref) => ref.watch(repositoryProvider).fetchTickets(),
);

/// "Mes demandes": support tickets (same as the web portal).
class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(ticketsProvider);
    Future<void> refresh() => ref.refresh(ticketsProvider.future);

    Widget body;
    final list = tickets.value;
    if (list == null && tickets.hasError) {
      body = Center(
        child: RetryMessage(
          message: errorMessage(tickets.error!),
          onRetry: () => ref.invalidate(ticketsProvider),
        ),
      );
    } else if (list == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 5),
          children: [
            if (list.isEmpty) const EmptyText('Aucune demande'),
            for (final t in list)
              TicketRow(
                ticket: t,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TicketDetailScreen(ticketId: t.id),
                    ),
                  );
                  ref.invalidate(ticketsProvider);
                },
              ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Mes demandes',
              action: IconButton(
                tooltip: 'Nouvelle demande',
                onPressed: () async {
                  final created = await Navigator.of(context).push<Ticket>(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => const TicketCreateScreen(),
                    ),
                  );
                  if (created != null) ref.invalidate(ticketsProvider);
                },
                icon: const Icon(Icons.add, color: AppColors.blueGreen),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class TicketRow extends StatelessWidget {
  const TicketRow({super.key, required this.ticket, required this.onTap});

  final Ticket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = ticket.isActive ? AppColors.blue : AppColors.greyText;
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        ticket.ticketTypeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.greyText),
                      ),
                    ),
                    Text(
                      ticket.statusLabel.isEmpty ? ticket.status : ticket.statusLabel,
                      style: TextStyle(color: statusColor),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatDate(ticket.createdAt),
                      style: const TextStyle(color: AppColors.greyText),
                    ),
                  ],
                ),
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: statusColor,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(5, 5, 5, 10),
                child: Text(
                  ticket.title,
                  style: const TextStyle(color: AppColors.gray, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
