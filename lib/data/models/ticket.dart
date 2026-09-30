import '../../core/utils/json.dart';

/// Ticket types accepted by `POST tickets/`.
const ticketTypes = <String, String>{
  'access': "Demande d'accès",
  'bug': 'Anomalie',
  'dashboard': 'Nouveau tableau de bord',
  'refresh': 'Actualisation des données',
  'other': 'Autre',
};

const ticketPriorities = <String, String>{
  'low': 'Basse',
  'medium': 'Moyenne',
  'high': 'Haute',
};

class Ticket {
  const Ticket({
    required this.id,
    required this.title,
    this.description = '',
    this.ticketType = 'other',
    this.ticketTypeLabel = '',
    this.priority = 'medium',
    this.status = 'open',
    this.statusLabel = '',
    this.createdAt,
    this.updatedAt,
    this.messagesCount = 0,
    this.messages = const [],
  });

  factory Ticket.fromJson(Json json) {
    final type = asString(json['ticket_type'], 'other');
    return Ticket(
      id: asInt(json['id']),
      title: asString(json['title']),
      description: asString(json['description']),
      ticketType: type,
      ticketTypeLabel: asString(
        json['ticket_type_label'],
        ticketTypes[type] ?? type,
      ),
      priority: asString(json['priority'], 'medium'),
      status: asString(json['status'], 'open'),
      statusLabel: asString(json['status_label']),
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
      messagesCount: asInt(json['messages_count']),
      messages: asMapList(json['messages']).map(TicketMessage.fromJson).toList(),
    );
  }

  final int id;
  final String title;
  final String description;
  final String ticketType;
  final String ticketTypeLabel;
  final String priority;
  final String status;
  final String statusLabel;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int messagesCount;
  final List<TicketMessage> messages;

  /// `open` / `in_progress` are highlighted in blue.
  bool get isActive => status == 'open' || status == 'in_progress';
}

class TicketMessage {
  const TicketMessage({
    required this.id,
    this.sender = '',
    this.isMine = false,
    this.content = '',
    this.createdAt,
  });

  factory TicketMessage.fromJson(Json json) => TicketMessage(
    id: asInt(json['id']),
    sender: asString(json['sender']),
    isMine: asBool(json['is_mine']),
    content: asString(json['content']),
    createdAt: asDate(json['created_at']),
  );

  final int id;
  final String sender;
  final bool isMine;
  final String content;
  final DateTime? createdAt;
}

/// Body of `POST tickets/`.
class NewTicket {
  const NewTicket({
    required this.title,
    required this.description,
    this.ticketType = 'other',
    this.priority = 'medium',
  });

  final String title;
  final String description;
  final String ticketType;
  final String priority;

  Json toJson() => {
    'title': title,
    'description': description,
    'ticket_type': ticketType,
    'priority': priority,
  };
}
