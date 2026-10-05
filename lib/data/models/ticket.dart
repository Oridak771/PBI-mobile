import 'dart:typed_data';

import '../../core/utils/json.dart';

/// `{value, label}` entry of `GET tickets/choices/`.
class TicketChoice {
  const TicketChoice(this.value, this.label);

  factory TicketChoice.fromJson(Json json) {
    final value = asString(json['value']);
    return TicketChoice(value, asString(json['label'], value));
  }

  final String value;
  final String label;
}

/// `GET tickets/choices/`: the web `TicketForm` choices.
///
/// [TicketChoices.defaults] mirrors the platform's `Ticket` model, used while
/// the server answer is loading or when it cannot be fetched.
class TicketChoices {
  const TicketChoices({
    required this.ticketTypes,
    required this.categories,
    required this.priorities,
    required this.statuses,
    this.isAdmin = false,
    this.maxAttachmentBytes = defaultMaxAttachmentBytes,
  });

  factory TicketChoices.fromJson(Json json) {
    List<TicketChoice> list(String key, List<TicketChoice> fallback) {
      final parsed = asMapList(
        json[key],
      ).map(TicketChoice.fromJson).where((c) => c.value.isNotEmpty).toList();
      return parsed.isEmpty ? fallback : parsed;
    }

    final max = asInt(json['max_attachment_bytes']);
    return TicketChoices(
      ticketTypes: list('ticket_types', defaults.ticketTypes),
      categories: list('categories', defaults.categories),
      priorities: list('priorities', defaults.priorities),
      statuses: list('statuses', defaults.statuses),
      isAdmin: asBool(json['is_admin']),
      maxAttachmentBytes: max > 0 ? max : defaultMaxAttachmentBytes,
    );
  }

  /// 5 MB, the web form limit.
  static const defaultMaxAttachmentBytes = 5 * 1024 * 1024;

  static const defaults = TicketChoices(
    ticketTypes: [
      TicketChoice('bug', 'Signalement de bug'),
      TicketChoice('dashboard', 'Demande de dashboard'),
      TicketChoice('refresh', "Demande d'actualisation"),
      TicketChoice('access', "Demande d'accès"),
      TicketChoice('other', 'Autre'),
    ],
    categories: [
      TicketChoice('bibliotheque', 'Bibliothèque'),
      TicketChoice('cbi', 'CBI'),
    ],
    priorities: [
      TicketChoice('low', 'Basse'),
      TicketChoice('medium', 'Moyenne'),
      TicketChoice('high', 'Haute'),
    ],
    statuses: [
      TicketChoice('open', 'Ouvert'),
      TicketChoice('in_progress', 'En cours'),
      TicketChoice('closed', 'Fermé'),
      TicketChoice('rejected', 'Rejeté'),
    ],
  );

  final List<TicketChoice> ticketTypes;
  final List<TicketChoice> categories;
  final List<TicketChoice> priorities;
  final List<TicketChoice> statuses;
  final bool isAdmin;
  final int maxAttachmentBytes;

  /// Label of [value] in [choices], [value] itself when unknown.
  static String labelOf(List<TicketChoice> choices, String value) {
    for (final c in choices) {
      if (c.value == value) return c.label;
    }
    return value;
  }

  static bool contains(List<TicketChoice> choices, String value) =>
      choices.any((c) => c.value == value);

  TicketChoices copyWith({bool? isAdmin}) => TicketChoices(
    ticketTypes: ticketTypes,
    categories: categories,
    priorities: priorities,
    statuses: statuses,
    isAdmin: isAdmin ?? this.isAdmin,
    maxAttachmentBytes: maxAttachmentBytes,
  );
}

/// `created_by` / `assigned_to` / message `author` / `GET tickets/admins/`.
class TicketPerson {
  const TicketPerson({
    required this.id,
    required this.name,
    this.initials = '',
    this.avatarColor,
  });

  static TicketPerson? fromJsonOrNull(Object? json) {
    if (json is! Map) return null;
    final map = asMap(json);
    return TicketPerson(
      id: asInt(map['id']),
      name: asString(map['name']),
      initials: asString(map['initials']),
      avatarColor: asStringOrNull(map['avatar_color']),
    );
  }

  final int id;
  final String name;
  final String initials;
  final String? avatarColor;

  @override
  bool operator ==(Object other) =>
      other is TicketPerson && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

class Ticket {
  const Ticket({
    required this.id,
    required this.title,
    this.description = '',
    this.ticketType = 'other',
    this.ticketTypeLabel = '',
    this.category = 'cbi',
    this.categoryLabel = '',
    this.priority = 'medium',
    this.priorityLabel = '',
    this.status = 'open',
    this.statusLabel = '',
    this.createdBy,
    this.assignedTo,
    this.attachmentUrl,
    this.createdAt,
    this.updatedAt,
    this.messagesCount = 0,
    this.messages = const [],
    this.canManage = false,
  });

  factory Ticket.fromJson(Json json) {
    final d = TicketChoices.defaults;
    final type = asString(json['ticket_type'], 'other');
    final category = asString(json['category'], 'cbi');
    final priority = asString(json['priority'], 'medium');
    final status = asString(json['status'], 'open');
    final messages = asMapList(
      json['messages'],
    ).map(TicketMessage.fromJson).toList();
    return Ticket(
      id: asInt(json['id']),
      title: asString(json['title']),
      description: asString(json['description']),
      ticketType: type,
      ticketTypeLabel: asString(
        json['ticket_type_label'],
        TicketChoices.labelOf(d.ticketTypes, type),
      ),
      category: category,
      categoryLabel: asString(
        json['category_label'],
        TicketChoices.labelOf(d.categories, category),
      ),
      priority: priority,
      priorityLabel: asString(
        json['priority_label'],
        TicketChoices.labelOf(d.priorities, priority),
      ),
      status: status,
      statusLabel: asString(
        json['status_label'],
        TicketChoices.labelOf(d.statuses, status),
      ),
      createdBy: TicketPerson.fromJsonOrNull(json['created_by']),
      assignedTo: TicketPerson.fromJsonOrNull(json['assigned_to']),
      attachmentUrl: asStringOrNull(json['attachment_url']),
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
      messagesCount: json.containsKey('messages_count')
          ? asInt(json['messages_count'])
          : messages.length,
      messages: messages,
      canManage: asBool(json['can_manage']),
    );
  }

  final int id;
  final String title;
  final String description;
  final String ticketType;
  final String ticketTypeLabel;
  final String category;
  final String categoryLabel;
  final String priority;
  final String priorityLabel;
  final String status;
  final String statusLabel;
  final TicketPerson? createdBy;
  final TicketPerson? assignedTo;
  final String? attachmentUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int messagesCount;
  final List<TicketMessage> messages;

  /// `GET tickets/<id>/` only: the viewer may change status / assignee.
  final bool canManage;

  /// `open` / `in_progress`: still being handled.
  bool get isActive => status == 'open' || status == 'in_progress';

  Ticket copyWith({
    String? status,
    String? statusLabel,
    TicketPerson? Function()? assignedTo,
    List<TicketMessage>? messages,
    int? messagesCount,
    DateTime? updatedAt,
    bool? canManage,
  }) => Ticket(
    id: id,
    title: title,
    description: description,
    ticketType: ticketType,
    ticketTypeLabel: ticketTypeLabel,
    category: category,
    categoryLabel: categoryLabel,
    priority: priority,
    priorityLabel: priorityLabel,
    status: status ?? this.status,
    statusLabel: statusLabel ?? this.statusLabel,
    createdBy: createdBy,
    assignedTo: assignedTo == null ? this.assignedTo : assignedTo(),
    attachmentUrl: attachmentUrl,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    messagesCount: messagesCount ?? this.messagesCount,
    messages: messages ?? this.messages,
    canManage: canManage ?? this.canManage,
  );

  /// Server answer of `POST tickets/<id>/update/` (no messages) merged into
  /// the detailed ticket.
  Ticket mergeUpdate(Ticket updated) => Ticket(
    id: id,
    title: updated.title.isEmpty ? title : updated.title,
    description: updated.description.isEmpty
        ? description
        : updated.description,
    ticketType: updated.ticketType,
    ticketTypeLabel: updated.ticketTypeLabel,
    category: updated.category,
    categoryLabel: updated.categoryLabel,
    priority: updated.priority,
    priorityLabel: updated.priorityLabel,
    status: updated.status,
    statusLabel: updated.statusLabel,
    createdBy: updated.createdBy ?? createdBy,
    assignedTo: updated.assignedTo,
    attachmentUrl: updated.attachmentUrl ?? attachmentUrl,
    createdAt: updated.createdAt ?? createdAt,
    updatedAt: updated.updatedAt ?? updatedAt,
    messagesCount: messages.length > updated.messagesCount
        ? messages.length
        : updated.messagesCount,
    messages: messages,
    canManage: canManage,
  );
}

class TicketMessage {
  const TicketMessage({
    required this.id,
    this.sender = '',
    this.author,
    this.isMine = false,
    this.fromAdmin = false,
    this.content = '',
    this.attachmentUrl,
    this.createdAt,
  });

  factory TicketMessage.fromJson(Json json) => TicketMessage(
    id: asInt(json['id']),
    sender: asString(json['sender']),
    author: TicketPerson.fromJsonOrNull(json['author']),
    isMine: asBool(json['is_mine']),
    fromAdmin: asBool(json['from_admin']),
    content: asString(json['content']),
    attachmentUrl: asStringOrNull(json['attachment_url']),
    createdAt: asDate(json['created_at']),
  );

  final int id;
  final String sender;
  final TicketPerson? author;
  final bool isMine;

  /// Sent by a BI administrator ("Admin BI" badge).
  final bool fromAdmin;
  final String content;
  final String? attachmentUrl;
  final DateTime? createdAt;

  /// Author name to display.
  String get authorName =>
      author?.name.isNotEmpty == true ? author!.name : sender;
}

/// `GET tickets/` answer.
class TicketList {
  const TicketList({this.isAdmin = false, this.tickets = const []});

  factory TicketList.fromJson(Json json) => TicketList(
    isAdmin: asBool(json['is_admin']),
    tickets: asMapList(json['tickets']).map(Ticket.fromJson).toList(),
  );

  final bool isAdmin;
  final List<Ticket> tickets;
}

/// List filter: one status (or all) and, for admins, "Assignés à moi".
class TicketFilter {
  const TicketFilter({this.status, this.assignedToMe = false});

  static const all = TicketFilter();

  /// `null`: every status.
  final String? status;
  final bool assignedToMe;

  /// Query of `GET tickets/`. `assigned=me` is only sent for admins (the
  /// server ignores it otherwise).
  Map<String, String> query({required bool isAdmin}) => {
    if (status != null && status!.isNotEmpty) 'status': status!,
    if (isAdmin && assignedToMe) 'assigned': 'me',
  };

  /// Same rule as the server, for local lists (demo, optimistic updates).
  bool matches(Ticket ticket, {required int? myId, required bool isAdmin}) {
    if (status != null && status!.isNotEmpty && ticket.status != status) {
      return false;
    }
    if (isAdmin && assignedToMe && ticket.assignedTo?.id != myId) return false;
    return true;
  }

  TicketFilter withStatus(String? value) =>
      TicketFilter(status: value, assignedToMe: assignedToMe);

  TicketFilter withAssignedToMe(bool value) =>
      TicketFilter(status: status, assignedToMe: value);

  @override
  bool operator ==(Object other) =>
      other is TicketFilter &&
      other.status == status &&
      other.assignedToMe == assignedToMe;

  @override
  int get hashCode => Object.hash(status, assignedToMe);
}

/// Image attached to a new ticket or message (multipart `attachment`).
class TicketAttachment {
  const TicketAttachment({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;

  int get length => bytes.length;
}

/// Body of `POST tickets/` (multipart).
class NewTicket {
  const NewTicket({
    required this.title,
    required this.description,
    this.ticketType = 'other',
    this.category = 'cbi',
    this.priority = 'medium',
    this.attachment,
  });

  final String title;
  final String description;
  final String ticketType;
  final String category;
  final String priority;
  final TicketAttachment? attachment;

  /// Multipart text fields.
  Map<String, String> toFields() => {
    'title': title,
    'description': description,
    'ticket_type': ticketType,
    'category': category,
    'priority': priority,
  };
}

/// Body of `POST tickets/<id>/update/` (admins). Only the set parts are sent.
class TicketUpdate {
  const TicketUpdate.status(String this.status)
    : assigneeChanged = false,
      assignedTo = null;

  const TicketUpdate.assignee(this.assignedTo)
    : assigneeChanged = true,
      status = null;

  final String? status;
  final bool assigneeChanged;

  /// Admin id, `null` for "Non assigné".
  final int? assignedTo;

  Json toJson() => {
    'status': ?status,
    if (assigneeChanged) 'assigned_to': assignedTo,
  };
}
