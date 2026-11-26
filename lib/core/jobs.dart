import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'api.dart';
import 'store.dart';
import 'ui.dart';

/// Background upload queue for multi-fish purchases and hotel sales.
/// Jobs are saved on the phone, so they survive app restarts, and are sent one fish at a time.
class Jobs extends ChangeNotifier {
  Jobs._();
  static final Jobs i = Jobs._();

  final List<Map<String, dynamic>> list = [];
  final ValueNotifier<int> tick = ValueNotifier<int>(0);
  bool _busy = false, _ready = false;
  Timer? _t;

  Future<void> init() async {
    if (_ready) {
      kick();
      return;
    }
    _ready = true;
    final s = await Store.get('jobs');
    if (s != null) {
      try {
        for (final j in jsonDecode(s) as List) {
          list.add(Map<String, dynamic>.from(j as Map));
        }
      } catch (_) {}
    }
    for (final j in list) {
      for (final it in (j['items'] as List)) {
        if (it['st'] == 'sending') it['st'] = 'unsure';
      }
      if (j['status'] == 'running') j['status'] = 'waiting';
    }
    _t ??= Timer.periodic(const Duration(seconds: 30), (_) => kick());
    notifyListeners();
    kick();
  }

  Future<void> _save() => Store.set('jobs', jsonEncode(list));

  Future<void> add(Map<String, dynamic> job) async {
    list.add(job);
    await _save();
    notifyListeners();
    kick();
  }

  Future<void> kick() async {
    if (_busy) return;
    _busy = true;
    try {
      for (final j in List<Map<String, dynamic>>.from(list)) {
        if (j['status'] != 'waiting') continue;
        final cont = await _run(j);
        if (!cont) break;
      }
    } finally {
      _busy = false;
    }
  }

  Map<String, dynamic> _body(Map j, Map it) => j['kind'] == 'sale'
      ? <String, dynamic>{
          'hotel_id': j['party_id'],
          'fish_id': it['fish_id'],
          'quantity': it['qty'],
          'journal_id': j['journal_id'],
          if (it['rate'] != null) 'rate': it['rate'],
        }
      : <String, dynamic>{
          'journal_id': j['journal_id'],
          'supplier_id': j['party_id'],
          'fish_id': it['fish_id'],
          'quantity': it['qty'],
          'rate': it['rate'],
          'paid_now': it['paid'],
          if (it['mode'] != null) 'payment_mode': it['mode'],
        };

  /// After a lost connection we are not sure the server got the entry. Check before sending again.
  Future<bool> _exists(Map j, Map it) async {
    final sale = j['kind'] == 'sale';
    final k = sale ? 'hotel_id' : 'supplier_id';
    final d = await Api.req(
        'GET', sale ? '/api/v1/hotel-sales' : '/api/v1/purchases',
        q: {'journal_id': '${j['journal_id']}', k: '${j['party_id']}'});
    for (final e in L(d is Map ? d['entries'] : d)) {
      if (e['fish_id'] == it['fish_id'] &&
          (nz(e['quantity']) - nz(it['qty'])).abs() < 0.0001 &&
          (it['rate'] == null ||
              (nz(e['rate']) - nz(it['rate'])).abs() < 0.0001)) {
        return true;
      }
    }
    return false;
  }

  /// Returns false when sending must pause (no internet / logged out / server asleep).
  Future<bool> _run(Map<String, dynamic> j) async {
    j['status'] = 'running';
    notifyListeners();
    final sale = j['kind'] == 'sale';
    for (final it in (j['items'] as List)) {
      final st = it['st'];
      if (st == 'done' || st == 'failed') continue;
      try {
        if (st == 'unsure' && await _exists(j, it)) {
          it['st'] = 'done';
          await _save();
          continue;
        }
        it['st'] = 'sending';
        await _save();
        await Api.req(
            'POST', sale ? '/api/v1/hotel-sales' : '/api/v1/purchases',
            body: _body(j, it));
        it['st'] = 'done';
        it['err'] = '';
        await _save();
      } on ApiException catch (e) {
        if (e.code == 0 || e.code == 401 || e.code >= 500) {
          if (it['st'] == 'sending') it['st'] = 'unsure';
          j['status'] = 'waiting';
          j['note'] = e.code == 401
              ? 'Please log in again. Entries are safe on the phone.'
              : 'No connection. Entries are safe on the phone and will be sent again.';
          await _save();
          notifyListeners();
          return false;
        }
        it['st'] = 'failed';
        it['err'] = e.message;
        await _save();
      }
    }
    final items = j['items'] as List;
    final failed = items.where((x) => x['st'] == 'failed').length;
    j['status'] = failed == 0 ? 'done' : 'failed';
    if (failed == 0) list.remove(j);
    await _save();
    notifyListeners();
    tick.value++;
    _announce(j);
    return true;
  }

  void _announce(Map<String, dynamic> j) {
    final items = j['items'] as List;
    final done = items.where((x) => x['st'] == 'done').length;
    final what = j['kind'] == 'sale' ? 'Sale' : 'Purchase';
    final ok = j['status'] == 'done';
    msgKey.currentState?.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        backgroundColor: ok ? teal : coral,
        content: Text(ok
            ? '$what saved: ${j['party']} • $done fish'
            : '$what problem: ${j['party']} • $done of ${items.length} saved. Check the red note.')));
  }

  Future<void> retryFailed(Map<String, dynamic> j) async {
    for (final it in (j['items'] as List)) {
      if (it['st'] == 'failed') it['st'] = 'todo';
    }
    j['status'] = 'waiting';
    await _save();
    notifyListeners();
    kick();
  }

  Future<void> dismiss(Map<String, dynamic> j) async {
    list.remove(j);
    await _save();
    notifyListeners();
    tick.value++;
  }
}

/// Shows pending / failed uploads. Hidden when nothing is waiting.
class JobTray extends StatelessWidget {
  const JobTray({super.key});

  Widget _card(Map<String, dynamic> j) {
    final items = j['items'] as List;
    final done = items.where((x) => x['st'] == 'done').length;
    final bad = items.where((x) => x['st'] == 'failed').toList();
    final failed = j['status'] == 'failed';
    final running = j['status'] == 'running';
    final what = j['kind'] == 'sale' ? 'Sale' : 'Purchase';
    final note = '${j['note'] ?? ''}';
    return Panel(
        pad: const EdgeInsets.fromLTRB(16, 12, 8, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (running)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(failed ? Icons.error_outline : Icons.cloud_upload_outlined,
                  color: failed ? coral : ocean),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    '$what • ${j['party']} • $done of ${items.length} saved',
                    style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
          if (failed)
            for (final x in bad)
              Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${x['fish']}: ${x['err']}',
                      style: const TextStyle(color: coral, fontSize: 13))),
          if (!failed && !running && note.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(note,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 13))),
          if (!running)
            Row(children: [
              TextButton(
                  onPressed: () =>
                      failed ? Jobs.i.retryFailed(j) : Jobs.i.kick(),
                  child: Text(failed ? 'Retry failed' : 'Send now')),
              if (failed)
                TextButton(
                    onPressed: () => Jobs.i.dismiss(j),
                    child: const Text('Dismiss')),
            ]),
        ]));
  }

  @override
  Widget build(BuildContext c) => AnimatedBuilder(
      animation: Jobs.i,
      builder: (c, _) {
        if (Jobs.i.list.isEmpty) return const SizedBox.shrink();
        return Column(children: [
          for (final j in List<Map<String, dynamic>>.from(Jobs.i.list)) _card(j)
        ]);
      });
}
