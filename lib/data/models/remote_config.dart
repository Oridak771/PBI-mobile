import '../../core/utils/json.dart';

/// `GET config/`.
class RemoteConfig {
  const RemoteConfig({
    this.minVersion = '0.0.0',
    this.latestVersion = '0.0.0',
    this.downloadUrl = '',
    this.contact = const Contact(),
    this.notificationPollSeconds = 60,
    this.serverTime,
  });

  factory RemoteConfig.fromJson(Json json) => RemoteConfig(
    minVersion: asString(json['min_version'], '0.0.0'),
    latestVersion: asString(json['latest_version'], '0.0.0'),
    downloadUrl: asString(json['download_url']),
    contact: Contact.fromJson(asMap(json['contact'])),
    notificationPollSeconds: asInt(json['notification_poll_seconds'], 60),
    serverTime: asDate(json['server_time']),
  );

  final String minVersion;
  final String latestVersion;
  final String downloadUrl;
  final Contact contact;
  final int notificationPollSeconds;
  final DateTime? serverTime;
}

class Contact {
  const Contact({
    this.email = 'cbi@groupe-hasnaoui.com',
    this.phone = '3004',
    this.website = 'https://cbi.groupe-hasnaoui.com',
  });

  factory Contact.fromJson(Json json) {
    const d = Contact();
    return Contact(
      email: asString(json['email'], d.email),
      phone: asString(json['phone'], d.phone),
      website: asString(json['website'], d.website),
    );
  }

  final String email;
  final String phone;
  final String website;

  /// Website without scheme, as displayed by the legacy app.
  String get websiteLabel =>
      website.replaceFirst(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/$'), '');
}
