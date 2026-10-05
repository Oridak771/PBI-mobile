import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/images/ticket_images.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/ticket.dart';

/// Foreground / background of a status pill: open & in progress = primary
/// tint, closed = success tint, rejected = danger tint.
({Color fg, Color bg}) ticketStatusColors(AppPalette palette, String status) =>
    switch (status) {
      'closed' => (
        fg: palette.success,
        bg: palette.success.withValues(alpha: 0.12),
      ),
      'rejected' => (
        fg: palette.danger,
        bg: palette.danger.withValues(alpha: 0.12),
      ),
      _ => (fg: palette.primaryText, bg: palette.primarySoft),
    };

/// Priority colour: high = danger, medium = amber, low = subtle.
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.isEmpty ? status : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.fg,
          fontSize: 12,
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
    this.fontSize = 12,
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
        Container(
          key: ValueKey('priority-dot-$priority'),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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

/// List row: title + status pill, priority / type / category, creator
/// (admins), relative date and message count.
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
    final muted = TextStyle(color: palette.textMuted, fontSize: 12.5);
    final creator = ticket.createdBy?.name ?? '';
    return AppCard(
      key: ValueKey('ticket-row-${ticket.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      onTap: onTap,
      color: selected ? palette.primarySoft : null,
      borderColor: selected ? palette.primary.withValues(alpha: 0.5) : null,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ticket.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: TicketStatusPill.of(ticket),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TicketPriority(
                priority: ticket.priority,
                label: ticket.priorityLabel,
              ),
              Text(ticket.ticketTypeLabel, style: muted),
              Text(ticket.categoryLabel, style: muted),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  [
                    if (showCreator && creator.isNotEmpty) creator,
                    relativeTimeFr(ticket.createdAt),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textSubtle, fontSize: 12),
                ),
              ),
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 14,
                color: palette.textSubtle,
                semanticLabel: 'Messages',
              ),
              const SizedBox(width: 3),
              Text(
                '${ticket.messagesCount}',
                style: TextStyle(color: palette.textSubtle, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
