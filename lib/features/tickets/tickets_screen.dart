import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/layout/adaptive.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/ticket.dart';
import '../shell/shell_header.dart';
import 'ticket_create_screen.dart';
import 'ticket_detail_screen.dart';
import 'ticket_widgets.dart';
import 'tickets_controller.dart';

/// "Tickets": the platform's ticket system (same as the web portal).
///
/// Compact / medium: the list, a ticket opens full screen. Expanded: list
/// and detail side by side. [inShell]: shown as a tab of the shell (title
/// without back button, room for the floating tab bar).
class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key, this.inShell = false});

  final bool inShell;

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
      final newButton = GradientButton(
        key: const Key('tickets-new'),
        label: 'Nouveau',
        icon: Icons.add_rounded,
        expand: false,
        height: 38,
        radius: 19,
        fontSize: 12.5,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        onPressed: () => _create(twoPane: twoPane),
      );
      final Widget header = widget.inShell
          ? ShellHeader(title: 'Tickets', trailing: newButton)
          : ScreenHeader(title: 'Tickets', titleSize: 20, action: newButton);
      final Widget content;
      if (!twoPane) {
        content = Column(
          children: [
            header,
            Expanded(child: list),
          ],
        );
      } else {
        final selected = _selected;
        content = Column(
          children: [
            header,
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: AdaptiveDimens.listPaneWidth, child: list),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: palette.divider,
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
        );
      }
      if (widget.inShell) return content;
      return GlassScaffold(
        body: SafeArea(bottom: false, child: content),
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
            padding: EdgeInsets.fromLTRB(
              gutter,
              4,
              gutter,
              24 + BottomBarInset.of(context),
            ),
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

/// Plural filter label of a status ("Ouverts", "En cours", "Fermés"…).
String ticketFilterLabel(TicketChoice status) => switch (status.value) {
  'open' => 'Ouverts',
  'in_progress' => 'En cours',
  'closed' => 'Fermés',
  'rejected' => 'Rejetés',
  _ => status.label,
};

/// Blurred segmented filter: "Tous / Ouverts / En cours / Fermés / Rejetés"
/// (+ "Assignés à moi" for admins), scrolling horizontally when needed.
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

  static const _all = '';
  static const _assigned = '#assigned-to-me';

  @override
  Widget build(BuildContext context) => CenteredContent(
    builder: (context, gutter) => Padding(
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 12),
      child: GlassSegmentedBar<String>(
        key: const Key('ticket-filters'),
        segments: [
          const GlassSegment(_all, 'Tous', key: Key('filter-all')),
          for (final s in statuses)
            GlassSegment(
              s.value,
              ticketFilterLabel(s),
              key: Key('filter-${s.value}'),
            ),
          if (showAssignedToMe)
            const GlassSegment(
              _assigned,
              'Assignés à moi',
              key: Key('filter-assigned'),
            ),
        ],
        selected: {
          filter.status ?? _all,
          if (filter.assignedToMe) _assigned,
        },
        onChanged: (value) {
          if (value == _assigned) {
            onChanged(filter.withAssignedToMe(!filter.assignedToMe));
          } else {
            onChanged(filter.withStatus(value == _all ? null : value));
          }
        },
      ),
    ),
  );
}
