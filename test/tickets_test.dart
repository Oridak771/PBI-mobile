import 'dart:async';
import 'dart:typed_data';

import 'package:cbi_mobile/core/errors/app_exception.dart';
import 'package:cbi_mobile/core/theme/app_palette.dart';
import 'package:cbi_mobile/data/models/ticket.dart';
import 'package:cbi_mobile/data/repositories/demo_fixtures.dart';
import 'package:cbi_mobile/features/settings/settings_view.dart';
import 'package:cbi_mobile/features/tickets/attachment_picker.dart';
import 'package:cbi_mobile/features/tickets/ticket_create_screen.dart';
import 'package:cbi_mobile/features/tickets/ticket_detail_screen.dart';
import 'package:cbi_mobile/features/tickets/ticket_widgets.dart';
import 'package:cbi_mobile/features/tickets/tickets_controller.dart';
import 'package:cbi_mobile/features/tickets/tickets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

/// Ticket shaped like MOBILE_API.md `GET tickets/<id>/`.
Map<String, dynamic> contractTicket() => {
  'id': 5,
  'title': 'Accès DRH',
  'description': 'Merci',
  'ticket_type': 'access',
  'ticket_type_label': "Demande d'accès",
  'category': 'bibliotheque',
  'category_label': 'Bibliothèque',
  'priority': 'high',
  'priority_label': 'Haute',
  'status': 'in_progress',
  'status_label': 'En cours',
  'created_by': {
    'id': 42,
    'name': 'Mohammed Bouhariz',
    'initials': 'MB',
    'avatar_color': '#358BA4',
  },
  'assigned_to': null,
  'attachment_url': '/mobile/v1/tickets/5/attachment/',
  'created_at': '2026-09-29T08:15:00+01:00',
  'updated_at': '2026-09-29T09:15:00+01:00',
  'messages_count': 2,
  'can_manage': true,
  'messages': [
    {
      'id': 1,
      'sender': 'Mohammed Bouhariz',
      'author': {'id': 42, 'name': 'Mohammed Bouhariz', 'initials': 'MB'},
      'is_mine': true,
      'from_admin': false,
      'content': 'Bonjour',
      'attachment_url': null,
      'created_at': '2026-09-29T08:16:00+01:00',
    },
    {
      'id': 2,
      'sender': 'Cellule BI',
      'author': {'id': 7, 'name': 'Cellule BI', 'initials': 'CB'},
      'is_mine': false,
      'from_admin': true,
      'content': 'En cours',
      'attachment_url': '/mobile/v1/tickets/5/messages/2/attachment/',
      'created_at': '2026-09-29T09:00:00+01:00',
    },
  ],
};

TicketAttachment image(int size, [String name = 'photo.jpg']) =>
    TicketAttachment(bytes: Uint8List(size), filename: name);

void main() {
  group('parsing', () {
    test('ticket with persons, labels, attachment and messages', () {
      final t = Ticket.fromJson(contractTicket());
      expect(t.id, 5);
      expect(t.category, 'bibliotheque');
      expect(t.categoryLabel, 'Bibliothèque');
      expect(t.priorityLabel, 'Haute');
      expect(t.statusLabel, 'En cours');
      expect(t.createdBy?.name, 'Mohammed Bouhariz');
      expect(t.createdBy?.avatarColor, '#358BA4');
      expect(t.assignedTo, isNull);
      expect(t.attachmentUrl, '/mobile/v1/tickets/5/attachment/');
      expect(t.canManage, isTrue);
      expect(t.isActive, isTrue);
      expect(t.messagesCount, 2);
      final admin = t.messages[1];
      expect(admin.fromAdmin, isTrue);
      expect(admin.isMine, isFalse);
      expect(admin.authorName, 'Cellule BI');
      expect(admin.attachmentUrl, contains('/messages/2/attachment/'));
      expect(t.messages.first.attachmentUrl, isNull);
    });

    test('missing labels fall back to the platform choices', () {
      final t = Ticket.fromJson({
        'id': 1,
        'title': 'x',
        'ticket_type': 'bug',
        'category': 'cbi',
        'priority': 'low',
        'status': 'rejected',
      });
      expect(t.ticketTypeLabel, 'Signalement de bug');
      expect(t.categoryLabel, 'CBI');
      expect(t.priorityLabel, 'Basse');
      expect(t.statusLabel, 'Rejeté');
      expect(t.canManage, isFalse);
      expect(t.createdBy, isNull);
    });

    test('choices, list and admins', () {
      final c = TicketChoices.fromJson(demoTicketChoicesJson(isAdmin: true));
      expect(c.ticketTypes.map((e) => e.value), contains('dashboard'));
      expect(c.categories.map((e) => e.label), ['Bibliothèque', 'CBI']);
      expect(c.statuses, hasLength(4));
      expect(c.isAdmin, isTrue);
      expect(c.maxAttachmentBytes, 5 * 1024 * 1024);
      // Empty / broken answers keep the defaults.
      final d = TicketChoices.fromJson({'ticket_types': 'x'});
      expect(d.ticketTypes, TicketChoices.defaults.ticketTypes);
      expect(d.maxAttachmentBytes, TicketChoices.defaultMaxAttachmentBytes);

      final list = TicketList.fromJson({
        'is_admin': true,
        'tickets': [contractTicket()],
      });
      expect(list.isAdmin, isTrue);
      expect(list.tickets.single.title, 'Accès DRH');
    });

    test('update body only carries what changed', () {
      expect(const TicketUpdate.status('closed').toJson(), {
        'status': 'closed',
      });
      expect(const TicketUpdate.assignee(7).toJson(), {'assigned_to': 7});
      expect(const TicketUpdate.assignee(null).toJson(), {'assigned_to': null});
      expect(
        const NewTicket(
          title: 't',
          description: 'd',
          ticketType: 'bug',
          category: 'bibliotheque',
          priority: 'high',
        ).toFields(),
        {
          'title': 't',
          'description': 'd',
          'ticket_type': 'bug',
          'category': 'bibliotheque',
          'priority': 'high',
        },
      );
    });
  });

  group('list filter', () {
    final open = Ticket.fromJson({
      'id': 1,
      'title': 'a',
      'status': 'open',
      'assigned_to': {'id': 42, 'name': 'Moi'},
    });
    final closed = Ticket.fromJson({'id': 2, 'title': 'b', 'status': 'closed'});

    test('query parameters', () {
      expect(TicketFilter.all.query(isAdmin: true), isEmpty);
      expect(const TicketFilter(status: 'open').query(isAdmin: false), {
        'status': 'open',
      });
      const mine = TicketFilter(status: 'closed', assignedToMe: true);
      expect(mine.query(isAdmin: true), {'status': 'closed', 'assigned': 'me'});
      expect(mine.query(isAdmin: false), {'status': 'closed'});
    });

    test('local matching follows the server rules', () {
      expect(
        TicketFilter.all.matches(closed, myId: 42, isAdmin: false),
        isTrue,
      );
      const openOnly = TicketFilter(status: 'open');
      expect(openOnly.matches(open, myId: 42, isAdmin: true), isTrue);
      expect(openOnly.matches(closed, myId: 42, isAdmin: true), isFalse);
      const assigned = TicketFilter(assignedToMe: true);
      expect(assigned.matches(open, myId: 42, isAdmin: true), isTrue);
      expect(assigned.matches(closed, myId: 42, isAdmin: true), isFalse);
      // Ignored for non-admins (like the server).
      expect(assigned.matches(closed, myId: 42, isAdmin: false), isTrue);
      expect(
        TicketFilter.all.withStatus('open').withAssignedToMe(true),
        const TicketFilter(status: 'open', assignedToMe: true),
      );
    });

    test('demo repository applies the filter and visibility', () async {
      final admin = FakeRepository();
      final all = await admin.fetchTickets();
      expect(all.isAdmin, isTrue);
      expect(all.tickets.map((t) => t.id), [5, 4, 2]);
      expect(all.tickets.every((t) => t.messages.isEmpty), isTrue);
      final closedOnly = await admin.fetchTickets(
        filter: const TicketFilter(status: 'closed'),
      );
      expect(closedOnly.tickets.map((t) => t.id), [2]);
      final mine = await admin.fetchTickets(
        filter: const TicketFilter(assignedToMe: true),
      );
      expect(mine.tickets.map((t) => t.id), [4]);

      final user = FakeRepository(ticketAdmin: false);
      final own = await user.fetchTickets();
      expect(own.isAdmin, isFalse);
      expect(own.tickets.map((t) => t.id), [5, 2], reason: 'own tickets only');
      expect((await user.fetchTicket(5)).canManage, isFalse);
    });
  });

  group('create form validation', () {
    final choices = TicketChoices.defaults;

    test('required fields', () {
      final errors = validateTicketForm(
        title: '  ',
        description: '',
        ticketType: null,
        category: 'nope',
        priority: 'medium',
        choices: choices,
      );
      expect(errors.keys, {
        TicketFields.title,
        TicketFields.description,
        TicketFields.ticketType,
        TicketFields.category,
      });
      expect(errors[TicketFields.title], 'Titre obligatoire');
    });

    test('valid form, title length and attachment size limit', () {
      Map<String, String> check({
        String title = 'Titre',
        TicketAttachment? a,
      }) => validateTicketForm(
        title: title,
        description: 'Description',
        ticketType: 'bug',
        category: 'cbi',
        priority: 'high',
        choices: choices,
        attachment: a,
      );
      expect(check(), isEmpty);
      expect(check(a: image(choices.maxAttachmentBytes)), isEmpty);
      final tooBig = check(a: image(choices.maxAttachmentBytes + 1));
      expect(tooBig.keys, [TicketFields.attachment]);
      expect(tooBig[TicketFields.attachment], contains('5 Mo'));
      expect(check(title: 'x' * 201).keys, [TicketFields.title]);
    });

    test('server errors are mapped to fields, the rest to a message', () {
      const error = ApiException(
        statusCode: 400,
        code: 'bad_request',
        detail: 'Ce champ est obligatoire.',
        errors: {
          'title': ['Ce champ est obligatoire.'],
          'attachment': ['Image trop lourde.', 'Autre'],
          '__all__': ['Formulaire invalide.'],
        },
      );
      final mapped = mapServerErrors(error);
      expect(mapped.fields, {
        'title': 'Ce champ est obligatoire.',
        'attachment': 'Image trop lourde.',
      });
      expect(mapped.message, 'Formulaire invalide.');

      final onlyFields = mapServerErrors(
        const ApiException(
          statusCode: 400,
          errors: {
            'description': ['Requis'],
          },
        ),
      );
      expect(onlyFields.fields, {'description': 'Requis'});
      expect(onlyFields.message, isNull);

      final network = mapServerErrors(const NetworkException());
      expect(network.fields, isEmpty);
      expect(network.message, ErrorMessages.network);
    });

    testWidgets('empty submit shows the errors under the fields', (
      tester,
    ) async {
      final repo = FakeRepository();
      await tester.pumpWidget(
        testApp(const TicketCreateScreen(), repo: repo, scaffold: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nouveau ticket'), findsOneWidget);
      // Type defaults to "Autre", catégorie CBI, priorité Moyenne.
      expect(find.text('Autre'), findsOneWidget);
      expect(find.text('CBI'), findsOneWidget);
      expect(find.text('Moyenne'), findsOneWidget);
      await tester.tap(find.text('Envoyer le ticket'));
      await tester.pumpAndSettle();
      expect(find.text('Titre obligatoire'), findsOneWidget);
      expect(find.text('Description obligatoire'), findsOneWidget);
      expect(repo.createdTickets, isEmpty);
    });

    testWidgets('too large image is rejected before upload', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final picker = FakeTicketImagePicker(image(6 * 1024 * 1024));
      await tester.pumpWidget(
        testApp(
          const TicketCreateScreen(),
          repo: FakeRepository(),
          imagePicker: picker,
          scaffold: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('ticket-attach')));
      await tester.tap(find.byKey(const Key('ticket-attach')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Galerie'));
      await tester.pumpAndSettle();
      expect(picker.sources, [AttachmentSource.gallery]);
      expect(find.byKey(const Key('attachment-preview')), findsNothing);
      expect(find.byKey(const Key('ticket-attachment-error')), findsOneWidget);
      expect(find.textContaining('5 Mo'), findsOneWidget);
    });

    testWidgets('sends the form with the picked image; server errors shown', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakeRepository()
        ..createTicketError = const ApiException(
          statusCode: 400,
          code: 'bad_request',
          detail: 'Titre déjà utilisé.',
          errors: {
            'title': ['Titre déjà utilisé.'],
          },
        );
      final picker = FakeTicketImagePicker(image(1000, 'capture.png'));
      await tester.pumpWidget(
        testApp(
          const TicketCreateScreen(
            initialType: 'access',
            initialTitle: 'Accès',
          ),
          repo: repo,
          imagePicker: picker,
          scaffold: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Demande d'accès"), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('ticket-description')),
        'Merci',
      );
      await tester.ensureVisible(find.byKey(const Key('ticket-attach')));
      await tester.tap(find.byKey(const Key('ticket-attach')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appareil photo'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('attachment-preview')), findsOneWidget);
      expect(find.text('capture.png'), findsOneWidget);

      await tester.tap(find.text('Envoyer le ticket'));
      await tester.pumpAndSettle();
      final sent = repo.createdTickets.single;
      expect(sent.title, 'Accès');
      expect(sent.ticketType, 'access');
      expect(sent.category, 'cbi');
      expect(sent.attachment?.filename, 'capture.png');
      // Field error from the server under "Titre".
      expect(find.text('Titre déjà utilisé.'), findsOneWidget);

      // Remove the image, fix and resend.
      await tester.tap(find.byKey(const Key('attachment-remove')));
      await tester.pump();
      expect(find.byKey(const Key('attachment-preview')), findsNothing);
      repo.createTicketError = null;
      await tester.enterText(find.byKey(const Key('ticket-title')), 'Accès 2');
      await tester.tap(find.text('Envoyer le ticket'));
      await tester.pumpAndSettle();
      expect(repo.createdTickets.last.attachment, isNull);
      expect(repo.createdTickets.last.title, 'Accès 2');
    });

    test('attachment filenames keep an image extension', () {
      expect(attachmentFilename('a.PNG'), 'a.PNG');
      expect(attachmentFilename('scaled_123'), 'scaled_123.jpg');
      expect(attachmentFilename(''), 'image.jpg');
    });
  });

  group('list screen', () {
    testWidgets('rows, filter chips and the admin "Assignés à moi" chip', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakeRepository();
      await tester.pumpWidget(
        testApp(const TicketsScreen(), repo: repo, scaffold: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tickets'), findsOneWidget);
      expect(find.text('Nouveau ticket'), findsOneWidget);
      for (final label in ['Tous', 'Ouvert', 'En cours', 'Fermé', 'Rejeté']) {
        expect(
          find.descendant(
            of: find.byKey(const Key('ticket-filters')),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
      expect(find.byKey(const Key('filter-assigned')), findsOneWidget);
      expect(find.byKey(const ValueKey('ticket-row-5')), findsOneWidget);
      // Creator shown to admins; priority dots coloured.
      expect(find.textContaining('Amina Benali'), findsOneWidget);
      expect(find.byKey(const ValueKey('priority-dot-high')), findsOneWidget);
      expect(find.byKey(const ValueKey('status-pill-closed')), findsWidgets);

      await tester.ensureVisible(find.byKey(const Key('filter-closed')));
      await tester.tap(find.byKey(const Key('filter-closed')));
      await tester.pumpAndSettle();
      expect(repo.ticketFilters.last, const TicketFilter(status: 'closed'));
      expect(find.byKey(const ValueKey('ticket-row-5')), findsNothing);
      expect(find.byKey(const ValueKey('ticket-row-2')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('filter-assigned')));
      await tester.tap(find.byKey(const Key('filter-assigned')));
      await tester.pumpAndSettle();
      expect(
        repo.ticketFilters.last,
        const TicketFilter(status: 'closed', assignedToMe: true),
      );
      expect(find.text('Aucun ticket pour ce filtre'), findsOneWidget);
    });

    testWidgets('non-admins: no "Assignés à moi", no creator names', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          const TicketsScreen(),
          repo: FakeRepository(ticketAdmin: false),
          scaffold: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('filter-assigned')), findsNothing);
      expect(find.textContaining('Utilisateur Démo'), findsNothing);
    });

    test('status and priority colours', () {
      const p = AppPalette.light;
      expect(ticketStatusColors(p, 'open').fg, p.primaryText);
      expect(ticketStatusColors(p, 'in_progress').fg, p.primaryText);
      expect(ticketStatusColors(p, 'closed').fg, p.success);
      expect(ticketStatusColors(p, 'rejected').fg, p.danger);
      expect(ticketPriorityColor(p, 'high'), p.danger);
      expect(ticketPriorityColor(p, 'medium'), p.warning);
      expect(ticketPriorityColor(p, 'low'), p.textSubtle);
    });
  });

  group('detail', () {
    testWidgets('header, conversation with the Admin BI badge, admin panel', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testApp(
          const TicketDetailScreen(ticketId: 4),
          repo: FakeRepository(),
          scaffold: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ticket #4'), findsOneWidget);
      expect(find.byKey(const Key('ticket-header')), findsOneWidget);
      expect(find.text('Signalement de bug'), findsOneWidget);
      expect(find.text('Amina Benali'), findsOneWidget);
      // Attachment thumbnails (ticket + message).
      expect(
        find.byKey(const ValueKey('attachment-${demoAttachmentPrefix}t4/')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('attachment-${demoAttachmentPrefix}m3/')),
        findsOneWidget,
      );
      // Message from an admin (mine here: no author header / badge).
      expect(find.byKey(const Key('ticket-admin-panel')), findsOneWidget);
      expect(find.text('Gestion du ticket'), findsOneWidget);
    });

    testWidgets(
      'no admin panel without can_manage; Admin BI badge on replies',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(412, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          testApp(
            const TicketDetailScreen(ticketId: 5),
            repo: FakeRepository(ticketAdmin: false),
            scaffold: false,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('ticket-admin-panel')), findsNothing);
        expect(find.text('Admin BI'), findsOneWidget);
        expect(find.text('Cellule BI'), findsWidgets);
      },
    );

    testWidgets('admin status change is optimistic and rolled back on error', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakeRepository()
        ..updateTicketGate = Completer<void>()
        ..updateTicketError = const ApiException(
          statusCode: 403,
          code: 'forbidden',
          detail: 'Refusé.',
        );
      await tester.pumpWidget(
        testApp(
          const TicketDetailScreen(ticketId: 5),
          repo: repo,
          scaffold: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('status-pill-open')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('admin-status-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fermé').last);
      await tester.pump();
      // Applied at once while the server answers.
      expect(find.byKey(const ValueKey('status-pill-closed')), findsOneWidget);
      expect(repo.ticketUpdates.single.$2.status, 'closed');

      repo.updateTicketGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('status-pill-open')), findsOneWidget);
      expect(find.text('Refusé.'), findsOneWidget);
    });

    testWidgets('admin assignee change is saved', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakeRepository();
      await tester.pumpWidget(
        testApp(
          const TicketDetailScreen(ticketId: 5),
          repo: repo,
          scaffold: false,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('admin-assignee-7-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Non assigné').last);
      await tester.pumpAndSettle();
      final update = repo.ticketUpdates.single.$2;
      expect(update.assigneeChanged, isTrue);
      expect(update.assignedTo, isNull);
      expect(find.text('Ticket mis à jour'), findsOneWidget);
      expect(
        (await tester.runAsync(() => repo.fetchTicket(5)))!.assignedTo,
        isNull,
      );
    });

    testWidgets('composer sends text with an image', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = FakeRepository();
      final picker = FakeTicketImagePicker(image(2000, 'shot.jpg'));
      await tester.pumpWidget(
        testApp(
          const TicketDetailScreen(ticketId: 2),
          repo: repo,
          imagePicker: picker,
          scaffold: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Aucun message pour le moment'), findsOneWidget);
      await tester.tap(find.byKey(const Key('composer-attach')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Galerie'));
      await tester.pumpAndSettle();
      expect(find.text('shot.jpg'), findsOneWidget);
      // Text is required with the image.
      await tester.tap(find.byKey(const Key('composer-send')));
      await tester.pump();
      expect(find.byKey(const Key('composer-error')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('composer-input')), 'Voici');
      await tester.tap(find.byKey(const Key('composer-send')));
      await tester.pumpAndSettle();
      expect(find.text('Voici'), findsOneWidget);
      expect(find.text('shot.jpg'), findsNothing);
      final sent = (await tester.runAsync(
        () => repo.fetchTicket(2),
      ))!.messages.single;
      expect(sent.attachmentUrl, isNotNull);
      expect(sent.isMine, isTrue);
    });
  });

  testWidgets('Paramètre shows the "Tickets" entry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testApp(const SettingsView(), repo: FakeRepository()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tickets'), findsOneWidget);
    expect(find.text('Mes demandes'), findsNothing);
    await tester.tap(find.text('Tickets'));
    await tester.pumpAndSettle();
    expect(find.byType(TicketsScreen), findsOneWidget);
  });
}
