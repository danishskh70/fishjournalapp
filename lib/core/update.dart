import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'config.dart';
import 'store.dart';
import 'ui.dart';

class Updates {
  static const _channel = MethodChannel('fish_journal/updater');
  static bool _done = false;

  static Future<void> onLaunch(BuildContext c) async {
    if (_done) return;
    _done = true;

    final info = await PackageInfo.fromPlatform();
    final seen = await Store.get('seen_version');

    if (seen != info.version) {
      await Store.set('seen_version', info.version);
      final notes = changelog[info.version];
      if (notes != null && c.mounted) {
        await whatsNew(c, info.version, notes);
      }
    }

    if (c.mounted) await check(c, manual: false);
  }

  static Future<void> whatsNew(
    BuildContext c,
    String v,
    List<String> notes,
  ) =>
      showDialog(
        context: c,
        builder: (_) => AlertDialog(
          title: Text("What's new in $v"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in notes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $s'),
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  static Future<Map<String, dynamic>?> latest() async {
    if (githubRepo.isEmpty) return null;

    try {
      final r = await http.get(
        Uri.parse(
          'https://api.github.com/repos/$githubRepo/releases/latest',
        ),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 15));

      if (r.statusCode == 404) {
        return {'status': 'no_release'};
      }

      if (r.statusCode != 200) {
        throw Exception('GitHub API error: ${r.statusCode}');
      }

      final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
      final assets = d['assets'];
      if (assets is! List) return null;

      for (final item in assets) {
        if (item is! Map) continue;

        final name = '${item['name'] ?? ''}';
        if (!name.toLowerCase().endsWith('.apk')) continue;

        final url = Uri.tryParse('${item['browser_download_url'] ?? ''}');
        if (url == null || url.scheme != 'https' || url.host != 'github.com') {
          return null;
        }

        return {
          'version': '${d['tag_name']}'.replaceFirst(
            RegExp(r'^[vV]'),
            '',
          ),
          'notes': '${d['body'] ?? ''}',
          'url': url.toString(),
          'size': item['size'] is num ? (item['size'] as num).toInt() : 0,
          'digest': '${item['digest'] ?? ''}',
        };
      }

      return {'status': 'no_apk'};
    } catch (_) {
      return null;
    }
  }

  static List<int> _parts(String s) => s
      .split('.')
      .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();

  static bool newer(String a, String b) {
    final x = _parts(a);
    final y = _parts(b);

    for (var i = 0; i < 3; i++) {
      final p = i < x.length ? x[i] : 0;
      final q = i < y.length ? y[i] : 0;
      if (p != q) return p > q;
    }

    return false;
  }

  static Future<void> check(
    BuildContext c, {
    required bool manual,
  }) async {
    if (githubRepo.isEmpty) {
      if (manual && c.mounted) toast(c, 'Update link is not set yet.');
      return;
    }

    final info = await PackageInfo.fromPlatform();
    final release = await latest();

    if (!c.mounted) return;

    if (release == null) {
      if (manual) {
        toast(c, 'Could not check for updates. Try again later.');
      }
      return;
    }

    if (release['status'] == 'no_apk') {
      if (manual) {
        toast(c, 'No APK is available in the latest release.');
      }
      return;
    }

    if (release['status'] == 'no_release') {
      if (manual) {
        toast(c, 'No release has been published yet.');
      }
      return;
    }

    if (!newer(release['version'] as String, info.version)) {
      if (manual) toast(c, 'You have the latest version (${info.version}).');
      return;
    }

    final notes = (release['notes'] as String).trim();
    final minimum = RegExp(
      r'min(?:imum)?\s*[:=]\s*v?(\d+(?:\.\d+){0,2})',
      caseSensitive: false,
    ).firstMatch(notes);

    final force = minimum != null && newer(minimum.group(1)!, info.version);

    if (!c.mounted) return;

    await showDialog(
      context: c,
      barrierDismissible: !force,
      builder: (_) => PopScope(
        canPop: !force,
        child: AlertDialog(
          title: Text(force ? 'Update required' : 'Update available'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version ${release['version']} is ready. '
                  'You have ${info.version}.',
                ),
                if (notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(notes),
                  ),
              ],
            ),
          ),
          actions: [
            if (!force)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(c),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: const Text('Later'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(c);
                        showDialog(
                          context: c,
                          barrierDismissible: !force,
                          builder: (_) => UpdateDownloadDialog(
                            release: release,
                            mandatory: force,
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: const Text('Download update'),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(c);
                    showDialog(
                      context: c,
                      barrierDismissible: false,
                      builder: (_) => UpdateDownloadDialog(
                        release: release,
                        mandatory: true,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Download update'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class UpdateDownloadDialog extends StatefulWidget {
  final Map<String, dynamic> release;
  final bool mandatory;

  const UpdateDownloadDialog({
    super.key,
    required this.release,
    required this.mandatory,
  });

  @override
  State<UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends State<UpdateDownloadDialog> {
  http.Client? _client;
  bool _downloading = false;
  bool _cancelled = false;
  String? _apkPath;
  String? _error;
  double _progress = 0;
  int _received = 0;
  int _total = 0;

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _cancelled = false;
      _error = null;
      _progress = 0;
      _received = 0;
    });

    final client = http.Client();
    _client = client;
    File? file;

    try {
      final uri = Uri.parse(widget.release['url'] as String);
      if (uri.scheme != 'https' || uri.host != 'github.com') {
        throw Exception('Invalid download address.');
      }

      final directory = await getTemporaryDirectory();
      final updateDir = Directory('${directory.path}/updates');
      await updateDir.create(recursive: true);

      file = File('${updateDir.path}/fish-journal-update.apk');
      if (await file.exists()) await file.delete();

      final response = await client
          .send(
            http.Request('GET', uri),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        throw Exception('Download failed (${response.statusCode}).');
      }

      _total = widget.release['size'] as int;
      if (_total > 0 &&
          response.contentLength != null &&
          response.contentLength != _total) {
        throw Exception('APK size does not match the release.');
      }

      final sink = file.openWrite();

      try {
        await for (final chunk in response.stream) {
          if (_cancelled) {
            throw Exception('Download cancelled.');
          }

          sink.add(chunk);
          _received += chunk.length;

          if (mounted && _total > 0) {
            setState(() {
              _progress = (_received / _total).clamp(0.0, 1.0);
            });
          }
        }

        await sink.flush();
      } finally {
        await sink.close();
      }

      if (_cancelled) throw Exception('Download cancelled.');

      if (_received == 0 || (_total > 0 && _received != _total)) {
        throw Exception('Downloaded APK is incomplete.');
      }

      final magic = await file.openRead(0, 4).fold<List<int>>(
        [],
        (previous, chunk) => previous..addAll(chunk),
      );

      if (magic.length < 4 || magic[0] != 0x50 || magic[1] != 0x4b) {
        throw Exception('The downloaded file is not a valid APK.');
      }

      final expected = (widget.release['digest'] as String)
          .replaceFirst(RegExp(r'^sha256:', caseSensitive: false), '')
          .toLowerCase();

      if (expected.isNotEmpty) {
        final actual = (await sha256.bind(file.openRead()).first).toString();
        if (actual.toLowerCase() != expected) {
          throw Exception('APK verification failed. Please try again.');
        }
      }

      if (!mounted) return;

      setState(() {
        _apkPath = file!.path;
        _downloading = false;
        _progress = 1;
      });
    } catch (e) {
      if (file != null && await file.exists()) {
        await file.delete();
      }

      if (!mounted) return;

      setState(() {
        _downloading = false;
        _error = _cancelled ? 'Download cancelled.' : e.toString();
      });
    } finally {
      client.close();
      _client = null;
    }
  }

  Future<void> _cancel() async {
    _cancelled = true;
    _client?.close();
    if (mounted) setState(() => _downloading = false);
  }

  Future<void> _install() async {
    if (_apkPath == null) return;

    try {
      final allowed =
          await Updates._channel.invokeMethod<bool>('canInstall') ?? false;

      if (!allowed) {
        await Updates._channel.invokeMethod('requestInstallPermission');

        if (!mounted) return;
        setState(() {
          _error = 'Allow Fish Khata to install apps in Android settings. '
              'Return here and tap Install update.';
        });
        return;
      }

      await Updates._channel.invokeMethod(
        'installApk',
        {'path': _apkPath},
      );
    } on PlatformException catch (e) {
      if (mounted)
        setState(() => _error = e.message ?? 'Could not open installer.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _cancelled = true;
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final version = widget.release['version'];

    return PopScope(
      canPop: !widget.mandatory && !_downloading,
      child: AlertDialog(
        title: Text('Update to $version'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_downloading) ...[
              const Text('Downloading update...'),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: _total > 0 ? _progress : null,
              ),
              const SizedBox(height: 8),
              Text(
                _total > 0
                    ? '${(_progress * 100).toStringAsFixed(0)}% '
                        '(${(_received / 1048576).toStringAsFixed(1)} / '
                        '${(_total / 1048576).toStringAsFixed(1)} MB)'
                    : '${(_received / 1048576).toStringAsFixed(1)} MB downloaded',
              ),
            ] else if (_apkPath != null) ...[
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 42,
              ),
              const SizedBox(height: 8),
              const Text(
                  'Download complete. APK verified and ready to install.'),
            ] else ...[
              const Text('Download the update using your internet connection.'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
        actions: [
          if (_downloading)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _cancel,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Cancel download'),
              ),
            )
          else
            Row(
              children: [
                if (!widget.mandatory) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: _apkPath != null ? _install : _download,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child:
                        Text(_apkPath != null ? 'Install update' : 'Download'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
