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

Json _report(int id, String name, String location, {bool favorite = false}) => {
  'id': id,
  'name': name,
  'description': '',
  'location': location,
  'server_id': 1,
  // In demo mode the viewer renders a local placeholder instead of this URL.
  'embed_url': 'http://10.20.10.63/Reports/powerbi/Demo/Rapport$id?rs:embed=true',
  'modified_at': _ago(const Duration(days: 2)),
  'favorite': favorite,
};

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
      _report(1, "Chiffre d'Affaires Groupe", 'Consolidé / DGR', favorite: true),
      _report(2, 'Tableau de bord Direction Générale', 'Consolidé / DGR'),
      _report(3, 'Suivi Budgétaire', 'Consolidé / DCG'),
      _report(4, 'Effectifs et Masse Salariale', 'Consolidé / DRH'),
      _report(5, 'Encaissement Clients', 'Consolidé / DFC', favorite: true),
      _report(6, 'Balance Âgée', 'Consolidé / DFC'),
      _report(7, 'Ventes par Région', 'Consolidé / DCO'),
      _report(8, 'Production Mensuelle', 'Pôle Industrie / Général'),
      _report(9, 'Stocks Matières Premières', 'Pôle Industrie / Général'),
      _report(10, 'Trésorerie Pôle Construction', 'Pôle Construction / DFC'),
      _report(11, 'Carnet de Commandes', 'Pôle Construction / DCO'),
      _report(12, 'Situation Financière', 'Société / DFC'),
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

List<Json> demoTicketsJson() => [
  {
    'id': 5,
    'title': "Demande d'accès aux rapports RH",
    'description': 'Merci de me donner accès aux rapports DRH.',
    'ticket_type': 'access',
    'ticket_type_label': "Demande d'accès",
    'priority': 'medium',
    'status': 'open',
    'status_label': 'Ouvert',
    'created_at': _ago(const Duration(days: 1)),
    'updated_at': _ago(const Duration(hours: 4)),
    'messages_count': 2,
    'messages': [
      {
        'id': 1,
        'sender': 'Utilisateur Démo',
        'is_mine': true,
        'content': 'Bonjour, pouvez-vous traiter ma demande ?',
        'created_at': _ago(const Duration(days: 1)),
      },
      {
        'id': 2,
        'sender': 'Cellule BI',
        'is_mine': false,
        'content': 'Bonjour, votre demande est en cours de validation.',
        'created_at': _ago(const Duration(hours: 4)),
      },
    ],
  },
];
