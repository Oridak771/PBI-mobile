/// Which edition / layout of a report the viewer shows (pure logic, unit
/// tested).
library;

import 'package:flutter/widgets.dart' show Orientation;

import '../../data/models/catalog.dart';

/// The user-facing choice: the "Mobile" / "Bureau" toolbar toggle.
enum ReportVariant {
  /// Portrait reading: the linked phone edition when there is one, else the
  /// full report drawn with its Power BI mobile (phone) layout.
  mobile,

  /// The full report with its desktop layout.
  desktop,
}

/// What is actually loaded in the WebView.
enum ViewerMode {
  /// `report.phone.embed_url`: a separate PBIRS report made for phones.
  phoneEdition,

  /// `embed_url` with the mobile-layout user scripts injected
  /// (`assets/js/pbi_mobile_layout.js`).
  mobileLayout,

  /// `embed_url` as PBIRS draws it (no user scripts).
  desktop;

  /// French label (technical info sheet).
  String get label => switch (this) {
    ViewerMode.phoneEdition => 'édition téléphone',
    ViewerMode.mobileLayout => 'mobile',
    ViewerMode.desktop => 'bureau',
  };
}

/// Variant to display: a manual choice ("Mobile" / "Bureau") wins for the
/// rest of the viewer session, otherwise portrait → mobile, landscape →
/// desktop.
ReportVariant selectReportVariant({
  required Orientation orientation,
  ReportVariant? manual,
}) {
  if (manual != null) return manual;
  return orientation == Orientation.portrait
      ? ReportVariant.mobile
      : ReportVariant.desktop;
}

/// Mode for [variant]: "mobile" is the phone edition when one is linked (it
/// keeps priority), else the mobile layout of the full report.
ViewerMode viewerModeFor(ReportVariant variant, {required bool hasPhoneEdition}) =>
    switch (variant) {
      ReportVariant.desktop => ViewerMode.desktop,
      ReportVariant.mobile =>
        hasPhoneEdition ? ViewerMode.phoneEdition : ViewerMode.mobileLayout,
    };

/// Whether the toolbar shows the "Mobile" / "Bureau" toggle: when a phone
/// edition exists or the backend reports a phone layout. Otherwise the choice
/// is left to the orientation (portrait still tries the mobile layout found
/// in the report itself).
bool showVariantToggle({
  required bool hasPhoneEdition,
  required bool mobileLayoutAvailable,
}) => hasPhoneEdition || mobileLayoutAvailable;

/// A viewer page load: mode + URL (+ whether the user scripts are injected).
typedef ViewerTarget = ({ViewerMode mode, ReportVariant variant, String url});

extension ViewerTargetScripts on ViewerTarget {
  /// Only the mobile layout mode injects the user scripts.
  bool get injectsScripts => mode == ViewerMode.mobileLayout;
}

/// Everything the viewer needs for one load, in one call.
ViewerTarget resolveViewerTarget({
  required Orientation orientation,
  required String fullUrl,
  PhoneEdition? phone,
  ReportVariant? manual,
}) {
  final phoneUrl = phone?.embedUrl.trim() ?? '';
  final variant = selectReportVariant(orientation: orientation, manual: manual);
  final mode = viewerModeFor(variant, hasPhoneEdition: phoneUrl.isNotEmpty);
  return (
    mode: mode,
    variant: variant,
    url: mode == ViewerMode.phoneEdition ? phoneUrl : fullUrl,
  );
}

/// Hosts the viewer may answer NTLM challenges for: every
/// `catalog.servers[].host` (this includes the phone edition's server), the
/// `server` of the open response, and the phone edition's server looked up by
/// `server_id`.
Set<String> viewerAllowedHosts({
  Catalog? catalog,
  PbiServer? openedServer,
  PhoneEdition? phone,
}) => {
  ...?catalog?.serverHosts,
  if (openedServer != null && openedServer.host.isNotEmpty)
    openedServer.host.toLowerCase(),
  ?catalog?.hostForServer(phone?.serverId),
};
