import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Controleert de nieuwste publieke GitHub-release van SamenThuis.
class UpdateService {
  static const _api =
      'https://api.github.com/repos/patrickpetri1988/samenthuis-updates/releases/latest';

  // Accepteert uitsluitend versies als v1.2.1 of 1.2.1+4.
  // Een ongeldige versie mag nooit tot een update-melding leiden.
  static List<int>? _versieDelen(String waarde) {
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:\+\d+)?$',
            caseSensitive: false)
        .firstMatch(waarde.trim());
    if (match == null) return null;
    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
  }

  static bool _isNieuwer(String online, String lokaal) {
    final a = _versieDelen(online);
    final b = _versieDelen(lokaal);
    if (a == null || b == null) return false;
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  static void _melding(BuildContext context, String tekst) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tekst)),
    );
  }

  static Future<void> controleer(BuildContext context,
      {bool toonOokGeenUpdate = false}) async {
    if (kIsWeb || !Platform.isAndroid) return;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final pakket = await PackageInfo.fromPlatform();
      if (!context.mounted) return;
      final lokaleVersie = pakket.version.trim();
      final request = await client.getUrl(Uri.parse(_api));
      request.headers.set(HttpHeaders.userAgentHeader, 'SamenThuis-Android');
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      if (!context.mounted) return;

      if (response.statusCode == 404) {
        if (toonOokGeenUpdate) {
          _melding(context, 'Er staat nog geen update op GitHub.');
        }
        return;
      }
      if (response.statusCode != 200) {
        throw HttpException('GitHub: ${response.statusCode}');
      }

      final responseBody = await response.transform(utf8.decoder).join();
      if (!context.mounted) return;
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final onlineVersie = (data['tag_name'] ?? '').toString().trim();

      // De handmatige controle toont beide versies, zodat we een eventuele
      // afwijking tussen Android en Flutter direct kunnen vaststellen.
      if (toonOokGeenUpdate) {
        _melding(context,
            'Op telefoon: $lokaleVersie · Op GitHub: $onlineVersie');
      }

      if (!_isNieuwer(onlineVersie, lokaleVersie)) {
        if (toonOokGeenUpdate) {
          _melding(context, 'SamenThuis is al bijgewerkt.');
        }
        return;
      }

      final assets = data['assets'] as List<dynamic>? ?? [];
      String? apkUrl;
      for (final item in assets) {
        if (item is Map &&
            (item['name'] ?? '').toString().toLowerCase().endsWith('.apk')) {
          apkUrl = item['browser_download_url']?.toString();
          break;
        }
      }
      if (apkUrl == null || !apkUrl.startsWith('https://')) return;
      if (!context.mounted) return;

      final downloaden = await showDialog<bool>(
        context: context,
        builder: (dialoogContext) => AlertDialog(
          title: const Text('Nieuwe SamenThuis-update!'),
          content: Text('Geïnstalleerd: $lokaleVersie\n'
              'Beschikbaar: $onlineVersie\n\n'
              'Wil je de APK downloaden? Android vraagt daarna om '
              'toestemming voor de installatie.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialoogContext, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialoogContext, true),
              child: const Text('Bijwerken'),
            ),
          ],
        ),
      );
      if (downloaden == true) {
        final gelukt = await launchUrl(Uri.parse(apkUrl),
            mode: LaunchMode.externalApplication);
        if (!context.mounted) return;
        if (!gelukt) {
          _melding(context, 'Download kon niet worden geopend.');
        }
      }
    } catch (e) {
      if (toonOokGeenUpdate && context.mounted) {
        _melding(context, 'Updatecontrole mislukt: $e');
      }
    } finally {
      client.close(force: true);
    }
  }
}
