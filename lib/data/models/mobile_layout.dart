import '../../core/utils/json.dart';

/// `GET reports/<id>/mobile-layout/`: the Power BI phone layout of a report
/// (Power BI Desktop → Mobile layout), extracted by the backend from the
/// .pbix. Placement only, no data.
class MobileLayout {
  const MobileLayout({
    this.available = false,
    this.version = 1,
    this.pages = const {},
  });

  /// No phone layout (or the backend could not read the .pbix).
  static const unavailable = MobileLayout();

  factory MobileLayout.fromJson(Json json) {
    final pages = <String, MobileLayoutPage>{};
    asMap(json['pages']).forEach((name, value) {
      if (name.isEmpty || value is! Map) return;
      pages[name] = MobileLayoutPage.fromJson(asMap(value));
    });
    return MobileLayout(
      available: asBool(json['available']),
      version: asInt(json['version'], 1),
      pages: pages,
    );
  }

  final bool available;
  final int version;

  /// Keyed by section (page) name; pages missing here have no phone layout.
  final Map<String, MobileLayoutPage> pages;

  /// `true` when there is something to inject into the report page.
  bool get hasPages => available && pages.isNotEmpty;

  /// The `window.__PBI_MOBILE_LAYOUT__` object read by
  /// `assets/js/pbi_mobile_layout.js`: `{pages: {…}}`.
  Json toScriptJson() => {
    'pages': {for (final e in pages.entries) e.key: e.value.toJson()},
  };
}

class MobileLayoutPage {
  const MobileLayoutPage({
    this.displayName = '',
    this.width = 0,
    this.height = 0,
    this.visuals = const {},
  });

  factory MobileLayoutPage.fromJson(Json json) {
    final visuals = <String, MobileLayoutVisual>{};
    asMap(json['visuals']).forEach((name, value) {
      if (name.isEmpty || value is! Map) return;
      visuals[name] = MobileLayoutVisual.fromJson(asMap(value));
    });
    return MobileLayoutPage(
      displayName: asString(json['display_name']),
      width: asDouble(json['width']),
      height: asDouble(json['height']),
      visuals: visuals,
    );
  }

  final String displayName;
  final double width;
  final double height;

  /// Keyed by visual name (`config.name` of the visual container).
  final Map<String, MobileLayoutVisual> visuals;

  Json toJson() => {
    'display_name': displayName,
    'width': width,
    'height': height,
    'visuals': {for (final e in visuals.entries) e.key: e.value.toJson()},
  };
}

/// Phone position of a visual, plus its phone-only formatting
/// (`Report/MobileState` objects, passed through untouched).
class MobileLayoutVisual {
  const MobileLayoutVisual({
    this.x = 0,
    this.y = 0,
    this.z = 0,
    this.width = 0,
    this.height = 0,
    this.objects,
  });

  factory MobileLayoutVisual.fromJson(Json json) {
    final objects = json['objects'];
    return MobileLayoutVisual(
      x: asDouble(json['x']),
      y: asDouble(json['y']),
      z: asDouble(json['z']),
      width: asDouble(json['width']),
      height: asDouble(json['height']),
      objects: objects is Map && objects.isNotEmpty ? asMap(objects) : null,
    );
  }

  final double x;
  final double y;
  final double z;
  final double width;
  final double height;
  final Json? objects;

  Json toJson() => {
    'x': x,
    'y': y,
    'z': z,
    'width': width,
    'height': height,
    'objects': ?objects,
  };
}
