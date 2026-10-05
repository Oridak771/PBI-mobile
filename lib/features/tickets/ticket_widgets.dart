import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/images/ticket_images.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../data/models/ticket.dart';

/// Foreground / background of a status pill: open = green, in progress =
/// amber, closed = teal green, rejected = red (25% / 22% tints).
({Color fg, Color bg}) ticketStatusColors(AppPalette palette, String status) =>
    switch (status) {
      'closed' => (
        fg: palette.success,
        bg: const Color(0xFF6FCF97).withValues(alpha: 0.22),
      ),
      'rejected' => (
        fg: palette.danger,
        bg: palette.danger.withValues(alpha: 0.22),
      ),
      'in_progress' => (
        fg: palette.isDark ? const Color(0xFFF3CD8F) : palette.warning,
        bg: const Color(0xFFE8B86A).withValues(alpha: 0.25),
      ),
      _ => (
        fg: palette.primaryBright,
        bg: palette.primary.withValues(alpha: 0.25),
      ),
    };

/// Priority colour: high = red, medium = amber, low = muted.
Color ticketPriorityColor(AppPalette palette, String priority) =>
    switch (priority) {
      'high' => palette.danger,
      'medium' => palette.warning,
      _ => palette.textSubtle,
    };

class TicketStatusPill extends StatelessWidget {
  const TicketStatusPill({
    super.key,
    required this.status,
    required this.label,
  });

  TicketStatusPill.of(Ticket ticket, {Key? key})
    : this(key: key, status: ticket.status, label: ticket.statusLabel);

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = ticketStatusColors(context.palette, status);
    return Container(
      key: ValueKey('status-pill-$status'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.isEmpty ? status : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Coloured dot + optional priority label.
class TicketPriority extends StatelessWidget {
  const TicketPriority({
    super.key,
    required this.priority,
    this.label,
    this.fontSize = 10.5,
  });

  final String priority;
  final String? label;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = ticketPriorityColor(palette, priority);
    final text = label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlowDot(
          key: ValueKey('priority-dot-$priority'),
          color: color,
          size: 7,
          glow: priority == 'high' ? 5 : 0,
        ),
        if (text != null && text.isNotEmpty) ...[
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textMuted, fontSize: fontSize),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Admin BI" badge of the messages sent by an administrator.
class AdminBadge extends StatelessWidget {
  const AdminBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: palette.primarySoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Admin BI',
        style: TextStyle(
          color: palette.primaryText,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Small initials avatar of a [TicketPerson].
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.person, this.size = 22});

  final TicketPerson person;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: parseHexColor(person.avatarColor),
    ),
    child: Text(
      person.initials.isEmpty ? '?' : person.initials.toUpperCase(),
      maxLines: 1,
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.4,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Ticket glass card: status pill, "type · category", relative date;
/// title; priority dot, creator (admins), assignee, attachment / message
/// indicators.
class TicketRow extends StatelessWidget {
  const TicketRow({
    super.key,
    required this.ticket,
    required this.onTap,
    this.showCreator = false,
    this.selected = false,
  });

  final Ticket ticket;
  final VoidCallback onTap;
  final bool showCreator;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final muted = TextStyle(color: palette.textMuted, fontSize: 10.5);
    final creator = ticket.createdBy?.name ?? '';
    final assignee = ticket.assignedTo?.name ?? '';
    final meta = [
      if (ticket.ticketTypeLabel.isNotEmpty) ticket.ticketTypeLabel,
      if (ticket.categoryLabel.isNotEmpty) ticket.categoryLabel,
    ].join(' · ');
    return AppCard(
      key: ValueKey('ticket-row-${ticket.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onTap,
      color: selected ? palette.primary.withValues(alpha: 0.16) : null,
      borderColor: selected ? palette.primary.withValues(alpha: 0.5) : null,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: TicketStatusPill.of(ticket),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ),
              const SizedBox(width: 6),
              Text(relativeShortFr(ticket.createdAt), style: muted),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            ticket.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              TicketPriority(
                priority: ticket.priority,
                label: ticket.priorityLabel,
              ),
              Expanded(
                child: Text(
                  [
                    if (showCreator && creator.isNotEmpty) creator,
                    if (assignee.isNotEmpty) 'Assigné : $assignee',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted.copyWith(height: 1.2),
                ).withLeadingGap(),
              ),
              if (ticket.attachmentUrl != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.attach_file_rounded,
                  size: 14,
                  color: palette.textMuted,
                  semanticLabel: 'Pièce jointe',
                ),
              ],
              if (ticket.messagesCount > 0) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 13,
                  color: palette.textMuted,
                  semanticLabel: 'Messages',
                ),
                const SizedBox(width: 3),
                Text('${ticket.messagesCount}', style: muted),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

extension on Text {
  /// 8px gap before a non-empty text.
  Widget withLeadingGap() => (data ?? '').isEmpty
      ? const SizedBox.shrink()
      : Padding(padding: const EdgeInsets.only(left: 8), child: this);
}

/// Attachment thumbnail (Bearer-authenticated); tap → full-screen viewer.
class TicketImageThumb extends ConsumerWidget {
  const TicketImageThumb({
    super.key,
    required this.url,
    this.width = 160,
    this.height = 120,
  });

  final String url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final image = ref.watch(ticketImageResolverProvider)(url);
    final placeholder = Container(
      width: width,
      height: height,
      color: palette.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: palette.textSubtle),
    );
    return Semantics(
      button: true,
      label: 'Pièce jointe',
      child: GestureDetector(
        key: ValueKey('attachment-$url'),
        onTap: image == null ? null : () => openImageViewer(context, image),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusControl),
          child: image == null
              ? placeholder
              : Image(
                  image: image,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : placeholder,
                  errorBuilder: (_, _, _) => Container(
                    width: width,
                    height: height,
                    color: palette.surfaceAlt,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: palette.textSubtle,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Full-screen, pinch-to-zoom image.
Future<void> openImageViewer(BuildContext context, ImageProvider image) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ImageViewerScreen(image: image),
      ),
    );

class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({super.key, required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        Positioned.fill(
          child: InteractiveViewer(
            key: const Key('image-viewer'),
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Image(
                image: image,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white70,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: IconButton(
              tooltip: 'Fermer',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}
