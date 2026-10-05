import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/layout/adaptive.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/ticket.dart';
import 'ticket_create_screen.dart';
import 'ticket_detail_screen.dart';
import 'ticket_widgets.dart';
import 'tickets_controller.dart';

/// "Tickets": the platform's ticket system (same as the web portal).
///
/// Compact / medium: the list, a ticket opens full screen. Expanded: list
/// and detail side by side.
class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key});

  @override
  ConsumerState<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends ConsumerState<TicketsScreen> {
  TicketFilter _filter = TicketFilter.all;

  /// Ticket shown in the right pane (expanded layout).
  int? _selected;

  void _refreshList() => ref.invalidate(ticketsProvider);

  Future<void> _create({required bool twoPane}) async {
    final created = await Navigator.of(context).push<Ticket>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const TicketCreateScreen(),
      ),
    );
    if (created == null || !mounted) return;
    _refreshList();
    if (twoPane) setState(() => _selected = created.id);
  }

  Future<void> _open(Ticket ticket, {required bool twoPane}) async {
    if (twoPane) {
      setState(() => _selected = ticket.id);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TicketDetailScreen(ticketId: ticket.id),
      ),
    );
    if (mounted) _refreshList();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final twoPane = WindowSize.of(constraints.maxWidth).isExpanded;
      final palette = context.palette;
      final list = TicketListPane(
        filter: _filter,
        selectedId: twoPane ? _selected : null,
        onFilter: (f) => setState(() => _filter = f),
        onOpen: (t) => _open(t, twoPane: twoPane),
      );
      final fab = FloatingActionButton.extended(
        key: const Key('tickets-new'),
        heroTag: 'tickets-new',
        onPressed: () => _create(twoPane: twoPane),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau ticket'),
      );
      if (!twoPane) {
        return Scaffold(
          floatingActionButton: fab,
          body: SafeArea(
            child: Column(
              children: [
                const ScreenHeader(title: 'Tickets'),
                Expanded(child: list),
              ],
            ),
          ),
        );
      }
      final selected = _selected;
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const ScreenHeader(title: 'Tickets'),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: AdaptiveDimens.listPaneWidth,
                      child: Stack(
                        children: [
                          Positioned.fill(child: list),
                          Positioned(right: 16, bottom: 16, child: fab),
                        ],
                      ),
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: palette.border,
                    ),
                    Expanded(
                      child: selected == null
                          ? const Center(
                              child: EmptyText(
                                'Sélectionnez un ticket',
                                icon: Icons.confirmation_number_outlined,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppDimens.page,
                                    4,
                                    AppDimens.page,
                                    4,
                                  ),
                                  child: Text(
                                    'Ticket #$selected',
                                    style: TextStyle(
                                      color: palette.textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TicketDetailView(
                                    key: ValueKey('detail-$selected'),
                                    ticketId: selected,
                                    onChanged: _refreshList,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Filter chips + ticket rows (pull-to-refresh, skeleton, empty state).
class TicketListPane extends ConsumerWidget {
  const TicketListPane({
    super.key,
    required this.filter,
    required this.onFilter,
    required this.onOpen,
    this.selectedId,
  });

  final TicketFilter filter;
  final ValueChanged<TicketFilter> onFilter;
  final ValueChanged<Ticket> onOpen;
  final int? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choices = ref.watch(currentTicketChoicesProvider);
    final async = ref.watch(ticketsProvider(filter));
    final data = async.value;
    final isAdmin = choices.isAdmin || (data?.isAdmin ?? false);
    Future<void> refresh() => ref.refresh(ticketsProvider(filter).future);

    final chips = TicketFilterChips(
      filter: filter,
      statuses: choices.statuses,
      showAssignedToMe: isAdmin,
      onChanged: onFilter,
    );

    Widget body;
    if (data == null && async.hasError) {
      body = Center(
        child: SingleChildScrollView(
          child: RetryMessage(
            message: errorMessage(async.error!),
            onRetry: () => ref.invalidate(ticketsProvider(filter)),
          ),
        ),
      );
    } else if (data == null) {
      body = const SkeletonList(count: 6, lines: 3);
    } else {
      body = RefreshIndicator(
        onRefresh: refresh,
        child: CenteredContent(
          builder: (context, gutter) => ListView(
            key: const Key('tickets-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 96),
            children: [
              if (data.tickets.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyText(
                    filter == TicketFilter.all
                        ? 'Aucun ticket'
                        : 'Aucun ticket pour ce filtre',
                    icon: Icons.confirmation_number_outlined,
                  ),
                ),
              for (final t in data.tickets)
                TicketRow(
                  ticket: t,
                  showCreator: isAdmin,
                  selected: t.id == selectedId,
                  onTap: () => onOpen(t),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chips,
        Expanded(child: body),
      ],
    );
  }
}

/// "Tous / Ouvert / En cours / Fermé / Rejeté" (+ "Assignés à moi" for
/// admins), scrolling horizontally on narrow screens.
class TicketFilterChips extends StatelessWidget {
  const TicketFilterChips({
    super.key,
    required this.filter,
    required this.statuses,
    required this.showAssignedToMe,
    required this.onChanged,
  });

  final TicketFilter filter;
  final List<TicketChoice> statuses;
  final bool showAssignedToMe;
  final ValueChanged<TicketFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget chip(String label, bool selected, VoidCallback onTap, {Key? key}) =>
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            key: key,
            label: Text(label),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onTap(),
            selectedColor: palette.primarySoft,
            backgroundColor: palette.surface,
            side: BorderSide(
              color: selected
                  ? palette.primary.withValues(alpha: 0.5)
                  : palette.border,
            ),
            labelStyle: TextStyle(
              color: selected ? palette.primaryText : palette.textMuted,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
            shape: const StadiumBorder(),
          ),
        );

    return CenteredContent(
      builder: (context, gutter) => SingleChildScrollView(
        key: const Key('ticket-filters'),
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(gutter, 4, gutter - 8, 8),
        child: Row(
          children: [
            chip(
              'Tous',
              filter.status == null,
              () => onChanged(filter.withStatus(null)),
              key: const Key('filter-all'),
            ),
            for (final s in statuses)
              chip(
                s.label,
                filter.status == s.value,
                () => onChanged(filter.withStatus(s.value)),
                key: Key('filter-${s.value}'),
              ),
            if (showAssignedToMe)
              chip(
                'Assignés à moi',
                filter.assignedToMe,
                () => onChanged(filter.withAssignedToMe(!filter.assignedToMe)),
                key: const Key('filter-assigned'),
              ),
          ],
        ),
      ),
    );
  }
}
