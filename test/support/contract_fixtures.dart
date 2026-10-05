/// Payload shaped like MOBILE_API.md `GET catalog/`.
Map<String, dynamic> contractCatalog() => {
  'generated_at': '2026-09-29T08:15:00+01:00',
  'servers': [
    {
      'id': 1,
      'name': 'PBIRS principal',
      'base_url': 'http://10.20.10.63',
      'host': '10.20.10.63',
      'scheme': 'http',
    },
    {
      'id': 2,
      'name': 'PBIRS mobile',
      'base_url': 'http://pbirs-mobile.gsh.local',
      'host': 'pbirs-mobile.gsh.local',
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
            {
              'key': 'direction:7',
              'name': 'Direction Finance et Comptabilité',
              'code': 'DFC',
              'report_ids': [12, 15],
            },
          ],
        },
      ],
    },
    {
      'key': 'societe',
      'title': 'Société',
      'layout': 'grid',
      'groups': [
        {
          'key': 'societe:9',
          'name': 'MDM',
          'code': 'MDM',
          'parent': 'Pôle Production',
          'logo_url': '/mobile/v1/metadata/9/logo/?v=societe-3f2a9c1b7d4e',
          'tabs': [
            {'key': 'general', 'name': 'Général', 'code': '', 'report_ids': [20]},
            {'key': 'empty', 'name': 'Vide', 'code': 'V', 'report_ids': []},
          ],
        },
        {'key': 'societe:10', 'name': 'Sans onglet', 'code': 'X', 'tabs': []},
      ],
    },
    {'key': 'biblio', 'title': 'Bibliothèque', 'layout': 'row', 'groups': []},
  ],
  'reports': {
    '12': {
      'id': 12,
      'name': 'Encaissement Clients',
      'description': '',
      'location': 'Consolidé / DFC',
      'server_id': 1,
      'embed_url': 'http://10.20.10.63/Reports/powerbi/x?rs:embed=true',
      'phone': {
        'id': 31,
        'server_id': 2,
        'embed_url':
            'http://pbirs-mobile.gsh.local/Reports/powerbi/x%20(t%C3%A9l%C3%A9phone)?rs:embed=true',
      },
      'modified_at': '2026-09-28T10:00:00+01:00',
      'favorite': true,
    },
    '15': {
      'id': 15,
      'name': 'Balance Âgée',
      'location': 'Consolidé / DFC',
      'server_id': 1,
      'embed_url': 'http://10.20.10.63/Reports/powerbi/y?rs:embed=true',
      'phone': null,
      'favorite': false,
    },
    '20': {
      'id': 20,
      'name': 'Achats',
      'location': 'Société / MDM',
      'server_id': 1,
      'embed_url': 'http://10.20.10.63/Reports/powerbi/z?rs:embed=true',
    },
  },
  'favorite_ids': [12, 20],
  'unread_notification_count': 3,
};
