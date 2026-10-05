import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/providers.dart';
import '../../data/models/ticket.dart';
import '../auth/session_controller.dart';

/// `GET tickets/choices/`; the platform defaults when it cannot be fetched.
final ticketChoicesProvider = FutureProvider<TicketChoices>((ref) async {
  try {
    return await ref.watch(repositoryProvider).fetchTicketChoices();
  } catch (_) {
    final admin = ref.read(sessionProvider).user?.isAdmin ?? false;
    return TicketChoices.defaults.copyWith(isAdmin: admin);
  }
});

/// Choices to use right now (defaults while loading).
final currentTicketChoicesProvider = Provider<TicketChoices>((ref) {
  final loaded = ref.watch(ticketChoicesProvider).value;
  if (loaded != null) return loaded;
  final admin = ref.watch(
    sessionProvider.select((s) => s.user?.isAdmin ?? false),
  );
  return TicketChoices.defaults.copyWith(isAdmin: admin);
});

/// `GET tickets/` for one filter.
final ticketsProvider = FutureProvider.autoDispose
    .family<TicketList, TicketFilter>(
      (ref, filter) =>
          ref.watch(repositoryProvider).fetchTickets(filter: filter),
    );

/// `GET tickets/admins/` (admins only): "Assigné à" choices.
final ticketAdminsProvider = FutureProvider.autoDispose<List<TicketPerson>>(
  (ref) => ref.watch(repositoryProvider).fetchTicketAdmins(),
);

/// Form fields of `POST tickets/` (server names, used for error mapping).
abstract final class TicketFields {
  static const title = 'title';
  static const description = 'description';
  static const ticketType = 'ticket_type';
  static const category = 'category';
  static const priority = 'priority';
  static const attachment = 'attachment';

  static const all = {
    title,
    description,
    ticketType,
    category,
    priority,
    attachment,
  };

  /// Same limit as the platform model.
  static const titleMaxLength = 200;
}

/// Client-side validation of the "Nouveau ticket" form: field → message.
Map<String, String> validateTicketForm({
  required String title,
  required String description,
  required String? ticketType,
  required String? category,
  required String? priority,
  required TicketChoices choices,
  TicketAttachment? attachment,
}) {
  final errors = <String, String>{};
  final t = title.trim();
  if (t.isEmpty) {
    errors[TicketFields.title] = 'Titre obligatoire';
  } else if (t.length > TicketFields.titleMaxLength) {
    errors[TicketFields.title] =
        '${TicketFields.titleMaxLength} caractères maximum';
  }
  if (description.trim().isEmpty) {
    errors[TicketFields.description] = 'Description obligatoire';
  }
  if (ticketType == null ||
      !TicketChoices.contains(choices.ticketTypes, ticketType)) {
    errors[TicketFields.ticketType] = 'Type obligatoire';
  }
  if (category == null ||
      !TicketChoices.contains(choices.categories, category)) {
    errors[TicketFields.category] = 'Catégorie obligatoire';
  }
  if (priority == null ||
      !TicketChoices.contains(choices.priorities, priority)) {
    errors[TicketFields.priority] = 'Priorité obligatoire';
  }
  if (attachment != null && attachment.length > choices.maxAttachmentBytes) {
    errors[TicketFields.attachment] = attachmentTooLarge(
      attachment.length,
      choices.maxAttachmentBytes,
    );
  }
  return errors;
}

String attachmentTooLarge(int size, int max) =>
    "L'image dépasse ${formatBytesFr(max)} (${formatBytesFr(size)}).";

/// Human size: `512 Ko`, `4,2 Mo`.
String formatBytesFr(int bytes) {
  if (bytes < 1024) return '$bytes o';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} Ko';
  final mb = bytes / (1024 * 1024);
  final text = mb == mb.roundToDouble()
      ? '${mb.round()}'
      : mb.toStringAsFixed(1);
  return '${text.replaceAll('.', ',')} Mo';
}

/// Server answer of a refused form (`400 {detail, errors}`): messages shown
/// under the known [fields], plus a general message (unknown fields,
/// `__all__`, or any other error) for a snackbar.
({Map<String, String> fields, String? message}) mapServerErrors(
  Object error, {
  Set<String> fields = TicketFields.all,
}) {
  if (error is! ApiException || error.errors.isEmpty) {
    return (fields: const {}, message: errorMessage(error));
  }
  final byField = <String, String>{};
  final other = <String>[];
  error.fieldErrors.forEach((field, message) {
    if (fields.contains(field)) {
      byField[field] = message;
    } else {
      other.add(message);
    }
  });
  return (
    fields: byField,
    message: other.isNotEmpty
        ? other.join('\n')
        : byField.isEmpty
        ? errorMessage(error)
        : null,
  );
}
