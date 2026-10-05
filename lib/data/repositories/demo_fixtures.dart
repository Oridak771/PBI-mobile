/// Fixture payloads shaped exactly like the CBI mobile API v1 responses.
/// Used by [DemoCbiRepository] and by the tests.
library;

import '../../core/utils/json.dart';

String _ago(Duration d) => DateTime.now().subtract(d).toIso8601String();

Json demoConfigJson() => {
  'min_version': '3.0.0',
  'latest_version': '3.0.0',
  'download_url': 'https://cbi.groupe-hasnaoui.com/mobile/cbi.apk',
  'contact': {
    'email': 'cbi@groupe-hasnaoui.com',
    'phone': '3004',
    'website': 'https://cbi.groupe-hasnaoui.com',
  },
  'notification_poll_seconds': 60,
  'server_time': DateTime.now().toIso8601String(),
};

Json demoUserJson() => {
  'id': 42,
  'username': 'demo',
  'name': 'Utilisateur Démo',
  'initials': 'UD',
  'email': 'demo@groupe-hasnaoui.com',
  'ad2000': 'H0000000',
  'role': 'admin',
  'is_admin': true,
  'direction': "Direction Système d'Information",
  'pole': 'Pôle Services',
  'company': 'GSH',
  'description': "Direction Système d'Information · GSH",
  'photo_url': null,
  'avatar_color': '#358BA4',
  'permissions': {
    'consolide': true,
    'pole': true,
    'direction': true,
    'module': true,
    'anomalie': true,
    'biblio': true,
  },
};

Json demoLoginJson() => {
  'token': 'demo-token',
  'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
  'user': demoUserJson(),
  'credentials': {'domain': 'GSH', 'username': 'demo'},
};

Json _report(
  int id,
  String name,
  String location, {
  bool favorite = false,
  bool phone = false,
  bool mobileLayout = false,
}) => {
  'id': id,
  'name': name,
  'description': '',
  'location': location,
  'server_id': 1,
  // In demo mode the viewer renders a local placeholder instead of this URL.
  'embed_url': 'http://10.20.10.63/Reports/powerbi/Demo/Rapport$id?rs:embed=true',
  'phone': phone
      ? {
          'id': 100 + id,
          'server_id': 1,
          'embed_url':
              'http://10.20.10.63/Reports/powerbi/Demo/Rapport$id%20(t%C3%A9l%C3%A9phone)?rs:embed=true',
        }
      : null,
  'modified_at': _ago(const Duration(days: 2)),
  'favorite': favorite,
  'has_mobile_layout': mobileLayout,
};

/// Sociétés of the demo catalog that have a logo (`logo_url`), mapped to the
/// bundled legacy images by [demoLogoAsset].
const _demoLogos = {'GAMMA', 'HPS', 'PUMA'};

String _demoLogoUrl(int optionId, String code) =>
    '/mobile/v1/metadata/$optionId/logo/?v=demo-${code.toLowerCase()}';

/// Bundled image standing for a demo `logo_url` (`?v=demo-<name>`), `null`
/// for any other URL.
String? demoLogoAsset(String logoUrl) {
  final version = Uri.tryParse(logoUrl)?.queryParameters['v'] ?? '';
  if (!version.startsWith('demo-')) return null;
  final name = version.substring(5);
  if (!_demoLogos.contains(name.toUpperCase())) return null;
  return 'assets/images/legacy/$name.png';
}

Json _tab(String key, String name, String code, List<int> ids) => {
  'key': key,
  'name': name,
  'code': code,
  'report_ids': ids,
};

Json demoCatalogJson() => {
  'generated_at': DateTime.now().toIso8601String(),
  'servers': [
    {
      'id': 1,
      'name': 'PBIRS principal',
      'base_url': 'http://10.20.10.63',
      'host': '10.20.10.63',
      'scheme': 'http',
    },
  ],
  'sections': [
    {
      'key': 'consolide',
      'title': 'Consolidé',
      'layout': 'row',
      'groups': [
        {
          'key': 'consolide',
          'name': 'Consolidé',
          'code': 'CONSOLIDE',
          'tabs': [
            _tab('direction:1', 'Direction Générale', 'DGR', [1, 2]),
            _tab('direction:2', 'Direction Contrôle de Gestion', 'DCG', [3]),
            _tab('direction:3', 'Direction Ressources Humaines', 'DRH', [4]),
            _tab('direction:7', 'Direction Finance et Comptabilité', 'DFC', [5, 6]),
            _tab('direction:8', 'Direction Commerciale', 'DCO', [7]),
          ],
        },
      ],
    },
    {
      'key': 'pole',
      'title': 'Pôle',
      'layout': 'row',
      'groups': [
        {
          'key': 'pole:1',
          'name': 'Pôle Industrie',
          'code': 'PI',
          'tabs': [_tab('general', 'Général', '', [8, 9])],
        },
        {
          'key': 'pole:2',
          'name': 'Pôle Construction',
          'code': 'PC',
          'tabs': [
            _tab('direction:7', 'Direction Finance et Comptabilité', 'DFC', [10]),
            _tab('direction:8', 'Direction Commerciale', 'DCO', [11]),
          ],
        },
      ],
    },
    {
      'key': 'societe',
      'title': 'Société',
      'layout': 'grid',
      'groups': [
        for (final (i, code) in const [
          'ALPOSTONE',
          'BTPH',
          'GAMMA',
          'GIRYAD',
          'GRANITTAM',
          'ALUMIX',
          'HPS',
          'PUMA',
        ].indexed)
          {
            'key': 'societe:${i + 1}',
            'name': code[0] + code.substring(1).toLowerCase(),
            'code': code,
            'parent': i.isEven ? 'Pôle Industrie' : 'Pôle Construction',
            if (_demoLogos.contains(code))
              'logo_url': _demoLogoUrl(100 + i, code),
            'tabs': [
              _tab('direction:7', 'Direction Finance et Comptabilité', 'DFC', [12]),
              _tab('direction:8', 'Direction Commerciale', 'DCO', [13]),
              _tab('direction:3', 'Direction Ressources Humaines', 'DRH', [14]),
            ],
          },
      ],
    },
    {
      'key': 'module',
      'title': 'Modules',
      'layout': 'row',
      'groups': [
        {
          'key': 'module:1',
          'name': 'Trésorerie',
          'code': 'TRE',
          'tabs': [_tab('general', 'Général', '', [15])],
        },
      ],
    },
  ],
  'reports': {
    for (final r in [
      _report(
        1,
        "Chiffre d'Affaires Groupe",
        'Consolidé / DGR',
        favorite: true,
        mobileLayout: true,
      ),
      _report(2, 'Tableau de bord Direction Générale', 'Consolidé / DGR'),
      _report(3, 'Suivi Budgétaire', 'Consolidé / DCG'),
      _report(4, 'Effectifs et Masse Salariale', 'Consolidé / DRH'),
      _report(
        5,
        'Encaissement Clients',
        'Consolidé / DFC',
        favorite: true,
        phone: true,
      ),
      _report(6, 'Balance Âgée', 'Consolidé / DFC'),
      _report(7, 'Ventes par Région', 'Consolidé / DCO', mobileLayout: true),
      _report(8, 'Production Mensuelle', 'Pôle Industrie / Général'),
      _report(9, 'Stocks Matières Premières', 'Pôle Industrie / Général'),
      _report(10, 'Trésorerie Pôle Construction', 'Pôle Construction / DFC'),
      _report(11, 'Carnet de Commandes', 'Pôle Construction / DCO'),
      _report(12, 'Situation Financière', 'Société / DFC', phone: true),
      _report(13, 'Chiffre d\'Affaires Société', 'Société / DCO'),
      _report(14, 'Absentéisme', 'Société / DRH'),
      _report(15, 'Position de Trésorerie', 'Modules / Trésorerie'),
    ])
      '${r['id']}': r,
  },
  'favorite_ids': [1, 5],
  'unread_notification_count': 2,
};

Json demoNotificationsJson() => {
  'notifications': [
    {
      'id': 8,
      'title': 'Accès',
      'kind': 'access',
      'message': 'Votre accès aux rapports Consolidé / DFC a été accordé.',
      'created_at': _ago(const Duration(minutes: 3)),
      'is_read': false,
      'is_new': true,
    },
    {
      'id': 7,
      'title': 'Rapport',
      'kind': 'report',
      'message': 'Le rapport « Encaissement Clients » a été actualisé.',
      'created_at': _ago(const Duration(hours: 2)),
      'is_read': false,
      'is_new': true,
    },
    {
      'id': 5,
      'title': 'Information',
      'kind': 'info',
      'message': 'Maintenance planifiée du serveur Power BI samedi à 22h.',
      'created_at': _ago(const Duration(days: 9)),
      'is_read': true,
      'is_new': false,
    },
  ],
  'unread_count': 2,
  'latest_id': 8,
};

Json demoHistoryItemJson(int id, int reportId, String name, String location,
        Duration ago, int duration) =>
    {
      'id': id,
      'report_id': reportId,
      'report_name': name,
      'location': location,
      'opened_at': _ago(ago),
      'duration_seconds': duration,
      'source': 'mobile',
    };

List<Json> demoHistoryJson() => [
  demoHistoryItemJson(991, 5, 'Encaissement Clients', 'Consolidé / DFC',
      const Duration(hours: 1), 184),
  demoHistoryItemJson(990, 1, "Chiffre d'Affaires Groupe", 'Consolidé / DGR',
      const Duration(days: 1, hours: 3), 612),
  demoHistoryItemJson(985, 8, 'Production Mensuelle',
      'Pôle Industrie / Général', const Duration(days: 4), 95),
];

Json demoHistoryUsersJson() => {
  'count': 2,
  'results': [
    {
      'user': {
        'id': 42,
        'name': 'Utilisateur Démo',
        'initials': 'UD',
        'description': "Direction Système d'Information",
        'company': 'GSH',
        'photo_url': null,
        'avatar_color': '#358BA4',
      },
      'last': demoHistoryJson().first,
    },
    {
      'user': {
        'id': 43,
        'name': 'Amina Benali',
        'initials': 'AB',
        'description': 'Direction Finance et Comptabilité',
        'company': 'Alpostone',
        'photo_url': null,
        'avatar_color': '#C24157',
      },
      'last': demoHistoryItemJson(980, 12, 'Situation Financière',
          'Société / DFC', const Duration(hours: 5), 240),
    },
  ],
};

/// Demo ticket attachments: any of these URLs maps to a bundled image
/// (see [demoAttachmentAsset]).
const demoAttachmentPrefix = '/mobile/v1/tickets/demo-attachment/';

/// Bundled image standing for a demo `attachment_url`, `null` otherwise.
String? demoAttachmentAsset(String url) =>
    url.startsWith(demoAttachmentPrefix) ? 'assets/images/legacy/gsh_logo_home.png' : null;

Json demoPersonJson(int id) => switch (id) {
  42 => {'id': 42, 'name': 'Utilisateur Démo', 'initials': 'UD', 'avatar_color': '#358BA4'},
  7 => {'id': 7, 'name': 'Cellule BI', 'initials': 'CB', 'avatar_color': '#71952B'},
  43 => {'id': 43, 'name': 'Amina Benali', 'initials': 'AB', 'avatar_color': '#C24157'},
  _ => {'id': id, 'name': 'Utilisateur $id', 'initials': 'U', 'avatar_color': '#8F9097'},
};

/// `GET tickets/choices/` (labels as the platform's `Ticket` model).
Json demoTicketChoicesJson({bool isAdmin = true}) => {
  'ticket_types': [
    {'value': 'bug', 'label': 'Signalement de bug'},
    {'value': 'dashboard', 'label': 'Demande de dashboard'},
    {'value': 'refresh', 'label': "Demande d'actualisation"},
    {'value': 'access', 'label': "Demande d'accès"},
    {'value': 'other', 'label': 'Autre'},
  ],
  'categories': [
    {'value': 'bibliotheque', 'label': 'Bibliothèque'},
    {'value': 'cbi', 'label': 'CBI'},
  ],
  'priorities': [
    {'value': 'low', 'label': 'Basse'},
    {'value': 'medium', 'label': 'Moyenne'},
    {'value': 'high', 'label': 'Haute'},
  ],
  'statuses': [
    {'value': 'open', 'label': 'Ouvert'},
    {'value': 'in_progress', 'label': 'En cours'},
    {'value': 'closed', 'label': 'Fermé'},
    {'value': 'rejected', 'label': 'Rejeté'},
  ],
  'is_admin': isAdmin,
  'max_attachment_bytes': 5 * 1024 * 1024,
};

/// `GET tickets/admins/`.
Json demoTicketAdminsJson() => {
  'admins': [demoPersonJson(7), demoPersonJson(42)],
};

Json _demoMessage(
  int id,
  int author,
  String content,
  Duration ago, {
  bool admin = false,
  bool attachment = false,
}) => {
  'id': id,
  'sender': demoPersonJson(author)['name'],
  'author': demoPersonJson(author),
  'is_mine': author == 42,
  'from_admin': admin,
  'content': content,
  'attachment_url': attachment ? '${demoAttachmentPrefix}m$id/' : null,
  'created_at': _ago(ago),
};

/// `GET tickets/<id>/` payloads (the list drops `messages` / `can_manage`).
List<Json> demoTicketsJson() => [
  {
    'id': 5,
    'title': "Demande d'accès aux rapports RH",
    'description': 'Merci de me donner accès aux rapports DRH.',
    'ticket_type': 'access',
    'ticket_type_label': "Demande d'accès",
    'category': 'cbi',
    'category_label': 'CBI',
    'priority': 'medium',
    'priority_label': 'Moyenne',
    'status': 'open',
    'status_label': 'Ouvert',
    'created_by': demoPersonJson(42),
    'assigned_to': demoPersonJson(7),
    'attachment_url': null,
    'created_at': _ago(const Duration(days: 1)),
    'updated_at': _ago(const Duration(hours: 4)),
    'messages_count': 2,
    'messages': [
      _demoMessage(1, 42, 'Bonjour, pouvez-vous traiter ma demande ?',
          const Duration(days: 1)),
      _demoMessage(2, 7, 'Bonjour, votre demande est en cours de validation.',
          const Duration(hours: 4), admin: true),
    ],
  },
  {
    'id': 4,
    'title': 'Chiffres de mars absents du rapport Trésorerie',
    'description':
        "Le rapport Trésorerie Pôle Construction n'affiche pas les données de mars.",
    'ticket_type': 'bug',
    'ticket_type_label': 'Signalement de bug',
    'category': 'cbi',
    'category_label': 'CBI',
    'priority': 'high',
    'priority_label': 'Haute',
    'status': 'in_progress',
    'status_label': 'En cours',
    'created_by': demoPersonJson(43),
    'assigned_to': demoPersonJson(42),
    'attachment_url': '${demoAttachmentPrefix}t4/',
    'created_at': _ago(const Duration(days: 3)),
    'updated_at': _ago(const Duration(days: 2)),
    'messages_count': 1,
    'messages': [
      _demoMessage(3, 42, 'Capture reçue, nous regardons la source.',
          const Duration(days: 2), admin: true, attachment: true),
    ],
  },
  {
    'id': 2,
    'title': 'Nouveau tableau de bord Achats',
    'description': 'Besoin d’un suivi mensuel des achats par fournisseur.',
    'ticket_type': 'dashboard',
    'ticket_type_label': 'Demande de dashboard',
    'category': 'bibliotheque',
    'category_label': 'Bibliothèque',
    'priority': 'low',
    'priority_label': 'Basse',
    'status': 'closed',
    'status_label': 'Fermé',
    'created_by': demoPersonJson(42),
    'assigned_to': null,
    'attachment_url': null,
    'created_at': _ago(const Duration(days: 20)),
    'updated_at': _ago(const Duration(days: 12)),
    'messages_count': 0,
    'messages': <Json>[],
  },
];

/// `GET reports/<id>/mobile-layout/`: odd report ids have a phone layout
/// (one page, two visuals), even ones none.
Json demoMobileLayoutJson(int reportId) => reportId.isEven
    ? {'available': false, 'version': 1, 'pages': <String, dynamic>{}}
    : {
        'available': true,
        'version': 1,
        'pages': {
          'ReportSection': {
            'display_name': 'Synthèse',
            'width': 320,
            'height': 640,
            'visuals': {
              'demoCard': {'x': 10, 'y': 10, 'z': 1000, 'width': 300, 'height': 120},
              'demoChart': {
                'x': 10,
                'y': 140,
                'z': 2000,
                'width': 300,
                'height': 260,
                'objects': {
                  'labels': [
                    {
                      'properties': {
                        'show': {
                          'expr': {'Literal': {'Value': 'true'}},
                        },
                      },
                    },
                  ],
                },
              },
            },
          },
        },
      };
