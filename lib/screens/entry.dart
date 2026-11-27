import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/jobs.dart';
import '../core/store.dart';
import '../core/ui.dart';
import '../core/result.dart';

/// Multi-fish entry for a purchase (from supplier) or a hotel sale.
/// 0 choose party -> 1 tick fish -> 2 kg and rate for all ticked fish on one screen -> 3 review and save.
/// Save puts a job in the background queue and returns at once.
class EntryFlow extends StatefulWidget {
  final bool sale;
  final int journalId;
  const EntryFlow({super.key, required this.sale, required this.journalId});
  @override
  State<EntryFlow> createState() => _EF();
}

class _EF extends State<EntryFlow> {
  int stage = 0;
  bool ready = false;
  String? err;
  List parties = [], fish = [];
  Map? party;
  final sel = <int>[];
  final qc = <int, TextEditingController>{};
  final rc = <int, TextEditingController>{};
  final hint = <int, String>{};
  final hotelRates = <int, String>{};
  final lastRate = <int, String>{};
  final paid = TextEditingController();
  String mode = 'cash';
  bool paidTouched = false;

  String get what => widget.sale ? 'Hotel sale' : 'Purchase';

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    try {
      final p =
          await fetch(widget.sale ? '/api/v1/hotels' : '/api/v1/suppliers');
      fish = await fetch('/api/v1/fish');
      final last = await Store.get('lastparty_${widget.sale ? 'sale' : 'buy'}');
      p.sort((a, b) =>
          (('${b['id']}' == last) ? 1 : 0) - (('${a['id']}' == last) ? 1 : 0));
      parties = p;
      err = null;
    } on ApiException catch (e) {
      err = e.message;
    }
    if (mounted) setState(() => ready = true);
  }

  String fishName(int id) =>
      '${fish.firstWhere((f) => f['id'] == id, orElse: () => <String, dynamic>{
            'name': '?'
          })['name']}';
  num effRate(int id) => n(rc[id]?.text ?? '');
  num amt(int id) => r2(n(qc[id]?.text ?? '') * effRate(id));
  num get total => sel.fold<num>(0, (a, id) => a + amt(id));

  Future<void> pickParty(Map p) async {
    sel.clear();
    qc.clear();
    rc.clear();
    hint.clear();
    hotelRates.clear();
    lastRate.clear();
    paidTouched = false;
    if (widget.sale) {
      try {
        final rates = await fetch('/api/v1/hotels/${p['id']}/rates');
        for (final m in rates) {
          hotelRates[m['fish_id'] as int] = fmt(nz(m['rate']));
        }
      } on ApiException catch (e) {
        if (mounted) toast(context, e.message);
        return;
      }
    }
    if (!widget.sale) {
      // newest rate paid to this supplier for each fish, from the server
      try {
        final d = await Api.req('GET', '/api/v1/purchases',
            q: {'supplier_id': '${p['id']}'});
        final best = <int, int>{};
        for (final e in L(M(d)['entries'])) {
          final fid = e['fish_id'] as int, pid = e['id'] as int;
          if (!best.containsKey(fid) || pid > best[fid]!) {
            best[fid] = pid;
            lastRate[fid] = fmt(nz(e['rate']));
          }
        }
      } catch (_) {}
    }
    await Store.set('lastparty_${widget.sale ? 'sale' : 'buy'}', '${p['id']}');
    if (!mounted) return;
    setState(() {
      party = p;
      stage = 1;
    });
  }

  void toggle(int id) {
    setState(() {
      if (sel.contains(id)) {
        sel.remove(id);
      } else {
        sel.add(id);
      }
    });
  }

  Future<void> addFish() async {
    final f = await newFishDialog(context);
    if (f == null || !mounted) return;
    setState(() {
      fish.add(f);
      sel.add(f['id'] as int);
    });
  }

  Future<void> toDetails() async {
    for (final id in sel) {
      if (qc.containsKey(id)) continue;
      qc[id] = TextEditingController();
      var d = '', h = '';
      if (widget.sale) {
        d = hotelRates[id] ?? '';
        h = d.isEmpty
            ? 'No agreed rate for this hotel. Type the rate.'
            : 'Agreed rate ₹$d. Change only for this sale.';
      } else {
        d = lastRate[id] ?? '';
        h = d.isEmpty
            ? 'First time from this supplier. Type rate.'
            : 'Last rate from this supplier ₹$d';
      }
      rc[id] = TextEditingController(text: d);
      hint[id] = h;
    }
    if (!mounted) return;
    setState(() => stage = 2);
  }

  bool tried = false;

  void next() {
    setState(() => tried = true);
    for (final id in sel) {
      if (n(qc[id]!.text) <= 0 || effRate(id) <= 0) {
        toast(context, 'Fill kg and rate for ${fishName(id)}');
        return;
      }
    }
    if (!paidTouched) paid.text = fmt(total);
    setState(() => stage = 3);
  }

  void back() {
    setState(() {
      if (stage > 0) stage--;
    });
  }

  void removeAt(int i) {
    setState(() {
      sel.removeAt(i);
      if (sel.isEmpty) stage = 1;
      if (!paidTouched) paid.text = fmt(total);
    });
  }

  Future<void> save() async {
    final t = total;
    var left = r2(n(paid.text));

    if (!widget.sale && (left < 0 || left > t + 0.001)) {
      toast(context, 'Paid cannot be more than total ₹${fmt(t)}');
      return;
    }

    final items = <Map<String, dynamic>>[];

    for (final id in sel) {
      final a = amt(id);
      final rateTxt = fmt(effRate(id));

      final it = <String, dynamic>{
        'fish_id': id,
        'fish': fishName(id),
        'qty': '${n(qc[id]!.text)}',
        'st': 'todo',
        'err': ''
      };

      if (widget.sale) {
        final def = hotelRates[id];
        it['rate'] = (def != null && n(def) == effRate(id)) ? null : rateTxt;
      } else {
        final pay = left >= a ? a : left;
        left = r2(left - pay);
        it['rate'] = rateTxt;
        it['paid'] = fmt(pay);
        it['mode'] = pay > 0 ? mode : null;
      }

      items.add(it);
    }

    // Create this once so retries use the same job ID.
    final job = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'kind': widget.sale ? 'sale' : 'purchase',
      'journal_id': widget.journalId,
      'party_id': party!['id'],
      'party': '${party!['name']}',
      'status': 'waiting',
      'note': '',
      'items': items,
    };

    final saved = await runWithResult(
      context,
      action: () => Jobs.i.add(job),
      working: 'Saving $what...',
      okTitle: '$what saved on this phone',
      okLines: (_) => [
        'Your entry is safely queued.',
        'It will sync in the background.',
      ],
    );

    if (!mounted) return;

    if (saved) {
      Navigator.pop(context, true);
    }
  }

  // ---------- stages ----------
  Widget stageParty() {
    if (parties.isEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                  widget.sale
                      ? 'No hotels yet. Add one in Settings > Hotels.'
                      : 'No suppliers yet. Add one in Settings > Suppliers.',
                  textAlign: TextAlign.center)));
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(widget.sale ? 'Which hotel?' : 'Which supplier?',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      for (final p in parties)
        Panel(
            onTap: () => pickParty(p as Map),
            child: Row(children: [
              CircleAvatar(
                  backgroundColor: tint(widget.sale ? teal : coral),
                  child: Icon(widget.sale ? Icons.hotel : Icons.local_shipping,
                      color: widget.sale ? teal : coral)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('${p['name']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 17))),
              const Icon(Icons.chevron_right),
            ])),
    ]);
  }

  Widget stageFish() => ListView(padding: const EdgeInsets.all(16), children: [
        Text('Which fish?',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const Text(
            'Tick all the fish first. Then enter kg and rate one by one.',
            style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in fish)
            FilterChip(
                label:
                    Text('${f['name']}', style: const TextStyle(fontSize: 15)),
                selected: sel.contains(f['id']),
                onSelected: (_) => toggle(f['id'] as int)),
          if (!widget.sale)
            ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('New fish'),
                onPressed: addFish),
        ]),
        if (fish.isEmpty) const EmptyNote('No fish yet. Tap New fish.'),
      ]);

  Widget stageDetail() =>
      ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Kg and rate',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const Text(
            'Fill each fish. Tap the next box on the keyboard to move on.',
            style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 12),
        for (final id in sel)
          Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                      child: Text(fishName(id),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800))),
                  Text(inr(amt(id)),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: numField(qc[id]!, 'Kg',
                          k: ValueKey('q$id'),
                          error:
                              tried && n(qc[id]!.text) <= 0 ? 'Type kg' : null,
                          onChanged: (_) => setState(() {}))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: numField(rc[id]!, 'Rate ₹/kg',
                          k: ValueKey('r$id'),
                          error: tried && effRate(id) <= 0 ? 'Type rate' : null,
                          onChanged: (_) => setState(() {}))),
                ]),
                if ((hint[id] ?? '').isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(hint[id]!,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12))),
              ])),
        Panel(
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              const Text('Total',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Text(inr(total),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 22))
            ])),
      ]);

  Widget stageReview() {
    final t = total;
    final p = r2(n(paid.text));
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('${party!['name']}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const Text('Check and save. Tap a fish to change it.',
          style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
      for (var i = 0; i < sel.length; i++)
        Panel(
            onTap: () => setState(() => stage = 2),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(fishName(sel[i]),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(
                        '${qty(n(qc[sel[i]]!.text))} kg × ${inr(effRate(sel[i]))}',
                        style: const TextStyle(color: Colors.black54)),
                  ])),
              Text(inr(amt(sel[i])),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
              IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => removeAt(i)),
            ])),
      Panel(
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
        Text(inr(t),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22))
      ])),
      if (!widget.sale) ...[
        numField(paid, 'Paid now (₹)',
            onChanged: (_) => setState(() => paidTouched = true)),
        const SizedBox(height: 10),
        SegmentedButton<String>(segments: const [
          ButtonSegment(
              value: 'cash', label: Text('Cash'), icon: Icon(Icons.payments)),
          ButtonSegment(
              value: 'upi', label: Text('UPI'), icon: Icon(Icons.qr_code))
        ], selected: {
          mode
        }, onSelectionChanged: (s) => setState(() => mode = s.first)),
        const SizedBox(height: 10),
        Panel(
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              const Text('Pending to supplier'),
              Text(inr(r2(t - p)),
                  style: TextStyle(
                      color: t - p > 0 ? coral : teal,
                      fontWeight: FontWeight.w800,
                      fontSize: 18))
            ])),
      ],
    ]);
  }

  Widget? bottom() {
    if (stage == 0) return null;
    Widget btn;
    if (stage == 1) {
      btn = FilledButton(
          onPressed: sel.isEmpty ? null : toDetails,
          child: Text(sel.isEmpty ? 'Tick fish' : 'Next (${sel.length} fish)'));
    } else if (stage == 2) {
      btn = FilledButton(onPressed: next, child: const Text('Review'));
    } else {
      btn = FilledButton(
          onPressed: sel.isEmpty ? null : save,
          child: Text(widget.sale ? 'Save sale' : 'Save purchase'));
    }
    return SafeArea(
        child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: btn));
  }

  @override
  Widget build(BuildContext c) {
    Widget body;
    if (!ready) {
      body = const Center(child: CircularProgressIndicator());
    } else if (err != null) {
      body = Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(err!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: () {
                      setState(() {
                        ready = false;
                      });
                      init();
                    },
                    child: const Text('Retry'))
              ])));
    } else if (stage == 0) {
      body = stageParty();
    } else if (stage == 1) {
      body = stageFish();
    } else if (stage == 2) {
      body = stageDetail();
    } else {
      body = stageReview();
    }
    return PopScope(
        canPop: stage == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) back();
        },
        child: Scaffold(
            appBar: AppBar(
                title:
                    Text(party == null ? what : '$what • ${party!['name']}')),
            bottomNavigationBar: ready && err == null ? bottom() : null,
            body: body));
  }
}
