import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'store.dart';
import 'ui.dart';

/// APK update notice. Reads the newest GitHub release of [githubRepo].
/// Release tag = version (v1.2.0). Attach the APK file to the release.
class Updates {
  static bool _done = false;

  static Future<void> onLaunch(BuildContext c) async {
    if (_done) return;
    _done = true;
    final info = await PackageInfo.fromPlatform();
    final seen = await Store.get('seen_version');
    if (seen != info.version) {
      await Store.set('seen_version', info.version);
      final notes = changelog[info.version];
      if (notes != null && c.mounted) await whatsNew(c, info.version, notes);
    }
    if (c.mounted) await check(c, manual: false);
  }

  static Future<void> whatsNew(BuildContext c, String v, List<String> notes) => showDialog(
      context: c,
      builder: (_) => AlertDialog(
              title: Text("What's new in $v"),
              content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final s in notes) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $s'))])),
              actions: [FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(100, 44)), onPressed: () => Navigator.pop(c), child: const Text('OK'))]));

  static Future<Map<String, String>?> latest() async {
    if (githubRepo.isEmpty) return null;
    try {
      final r = await http
          .get(Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest'), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
      var url = '${d['html_url'] ?? ''}';
      for (final a in L(d['assets'])) {
        if ('${a['name']}'.toLowerCase().endsWith('.apk')) {
          url = '${a['browser_download_url']}';
          break;
        }
      }
      return {'version': '${d['tag_name']}'.replaceFirst(RegExp(r'^[vV]'), ''), 'notes': '${d['body'] ?? ''}', 'url': url};
    } catch (_) {
      return null;
    }
  }

  static List<int> _parts(String s) => s.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();

  static bool newer(String a, String b) {
    final x = _parts(a), y = _parts(b);
    for (var i = 0; i < 3; i++) {
      final p = i < x.length ? x[i] : 0, q = i < y.length ? y[i] : 0;
      if (p != q) return p > q;
    }
    return false;
  }

  static Future<void> check(BuildContext c, {required bool manual}) async {
    if (githubRepo.isEmpty) {
      if (manual && c.mounted) toast(c, 'Update link is not set yet.');
      return;
    }
    final info = await PackageInfo.fromPlatform();
    final l = await latest();
    if (!c.mounted) return;
    if (l == null) {
      if (manual) toast(c, 'Could not check now. Try later.');
      return;
    }
    if (!newer(l['version']!, info.version)) {
      if (manual) toast(c, 'You have the latest version (${info.version}).');
      return;
    }
    final notes = l['notes']!.trim();
    // Put a line like  min: 1.2.0  in the release notes to force older apps to update.
    final m = RegExp(r'min(?:imum)?\s*[:=]\s*v?(\d+(?:\.\d+){0,2})', caseSensitive: false).firstMatch(notes);
    final force = m != null && newer(m.group(1)!, info.version);
    await showDialog(
        context: c,
        barrierDismissible: !force,
        builder: (_) => PopScope(canPop: !force, child: AlertDialog(
                title: Text(force ? 'Update required' : 'Update available'),
                content: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Version ${l['version']} is ready. You have ${info.version}.'),
                  if (notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(notes)),
                  const Padding(padding: EdgeInsets.only(top: 10), child: Text('Tap Download, then open the downloaded file and tap Install. Your data stays.', style: TextStyle(color: Colors.black54))),
                ])),
                actions: [
                  if (!force) TextButton(onPressed: () => Navigator.pop(c), child: const Text('Later')),
                  FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(110, 48)),
                      onPressed: () {
                        launchUrl(Uri.parse(l['url']!), mode: LaunchMode.externalApplication);
                        if (!force) Navigator.pop(c);
                      },
                      child: const Text('Download'))
                ])));
  }
}
