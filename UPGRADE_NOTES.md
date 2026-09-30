# CBI Upgrade Notes

This release upgrades the original CBI portal while preserving its purpose: a secure, internal workspace for accessing and administering Power BI Report Server (PBIRS) content. Existing operational concepts—users, authorizations, report access, history, messaging, and the dashboard—have been evolved into a more maintainable and scalable portal.

## What is new

### Modern, deployable platform

- Upgraded from the legacy Django 3 application to Django 5.1+ with a modular app structure.
- Centralized configuration through environment variables, including PBIRS, LDAP, database, and production-host settings.
- Added Docker and Docker Compose support for consistent deployments.
- Added production server guidance for Gunicorn and Waitress.
- Added dedicated settings for testing, logging, caching, and production operation.

### Secure identity and access management

- LDAP/Active Directory authentication replaces the legacy local login flow while retaining NTLM-compatible access to PBIRS.
- Role-based access control supports administrators and standard users, with granular permissions for Direction, Pôle, Consolidé, Module, and Anomalie views.
- Report-level permissions are stored locally and checked before reports can be opened.
- User management now includes roles, detailed user pages, permission management, group membership, company assignment, user history, and onboarding state.
- Access and administration activity is recorded in a user history/audit trail.

### PBIRS integration and report operations

- PBIRS REST API v2.0 access is now isolated behind a reusable service layer with centralized authentication, error handling, caching, and logging.
- Supports one or more PBIRS servers, including server configuration and per-report server URLs.
- Reports can be synchronized from PBIRS into a local metadata cache, avoiding repeated remote lookups for navigation and authorization.
- Administrators can upload, download, rename, move, replace, delete, and update report descriptions and metadata.
- Supports embedded report viewing, print, full-screen mode, and shareable links.
- Refresh plans, shared schedules, refresh status, and refresh history are available for supported reports.

### Organised report discovery

- Introduced virtual, business-oriented report views: Direction, Pôle, Bibliothèque, Consolidé, Module, and Anomalie.
- Reports can carry multiple metadata assignments (directions, pôles, companies, and modules), allowing one report to be surfaced in the appropriate business contexts.
- Added hierarchical folders, report assignment, ordering, moving, renaming, and removal without changing the physical PBIRS folder structure.
- Report pages now display a clickable breadcrumb trail at the top, showing the complete route used to reach the report—for example: `Pôle > Finance > Budget > Report`.
- Added flat, hierarchical, and folder-based report browsing experiences.

### Improved user experience

- Rebuilt the portal shell with responsive layouts, modern cards, consistent icons, and light/dark theme support.
- The navigation menu is permission-aware and highlights only the actual active item; hover feedback is stable and uses the same behavior in both themes.
- Added a landing page, onboarding, dashboard, notification center, empty/error states, and mobile sidebar behavior.
- Added an integrated ticketing module with categories, priorities, statuses, threaded messages, and file attachments.

### Administration and operational support

- Added in-app notifications for users.
- Added PBIRS permission synchronization tools, including a management command for scheduled or manual synchronization.
- Added administrative screens for missing users and missing permissions, making permission reconciliation easier.
- Added metadata-option management and PBIRS server management screens.

## Continuity with the original portal

The upgrade retains the original portal’s core business capabilities: report access, user authorizations, administrator tooling, dashboard access, history, messaging, and report presentation. The difference is that these functions are now delivered through a supported Django architecture, PBIRS service integration, stronger permission controls, richer navigation, and a responsive user interface that can grow with the organisation.

## Suggested rollout checks

1. Configure the required environment variables and migrate the database.
2. Register PBIRS server connections and run the report/permission synchronization.
3. Review user roles, business-view permissions, and report assignments.
4. Validate representative report paths, embedded access, refresh information, and ticket notifications with a standard user and an administrator.
