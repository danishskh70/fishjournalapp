import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/ui.dart';

/// Morning stock. Yesterday's closing is only a hint. Owner types what is really there.
class OpeningScreen extends StatefulWidget {
  final Map j;
  const OpeningScreen({super.key, required this.j});
  @override
  State<OpeningScreen> createState() => _OS();
}

class _OS extends State<OpeningScreen> {
  List fish = [];
  final cs = <int, TextEditingController>{};
  final prev = <int, num>{};
  final sel = <int>[];
  bool ok = false, busy = false;
  String? err;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    try {
      fish = await fetch('/api/v1/fish');
      final rows = L(M(widget.j['stock'])['rows']);
      for (final f in fish) {
        final id = f['id'] as int;
        final r = rows
            .cast<dynamic>()
            .firstWhere((x) => x['fish_id'] == id, orElse: () => null);
        final conf = r != null && r['opening_confirmed'] == true;
        final q = r == null
            ? 0
            : nz(conf ? r['opening_quantity'] : r['suggested_opening']);
        cs[id] = TextEditingController(text: q > 0 ? fmt(q) : '');
        prev[id] = r == null ? 0 : nz(r['previous_closing']);
        if (q > 0) sel.add(id);
      }
    } on ApiException catch (e) {
      err = e.message;
    }
    if (mounted) setState(() => ok = true);
  }

  String nm(int id) => '${fish.firstWhere((f) => f['id'] == id)['name']}';

  Future<void> add() async {
    final id = await sheet<int>(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Add fish',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in fish.where((f) => !sel.contains(f['id'])))
              ActionChip(
                  label: Text('${f['name']}'),
                  onPressed: () => Navigator.pop(context, f['id'] as int)),
            ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('New fish'),
                onPressed: () => Navigator.pop(context, -1)),
          ]),
        ]));
    if (id == null || !mounted) return;
    if (id == -1) {
      final f = await newFishDialog(context);
      if (f == null || !mounted) return;
      final nid = f['id'] as int;
      fish.add(f);
      cs[nid] = TextEditingController();
      prev[nid] = 0;
      setState(() => sel.add(nid));
    } else {
      setState(() => sel.add(id));
    }
  }

  Future<void> save() async {
    for (final id in sel) {
      if (!isNum(cs[id]!.text)) {
        toast(context, 'Type kg for ${nm(id)}. Type 0 if none.');
        return;
      }
    }
    setState(() => busy = true);
    try {
      await Api.req('PUT', '/api/v1/journals/${widget.j['id']}/opening-stock',
          body: {
            'items': [
              for (final f in fish)
                {
                  'fish_id': f['id'],
                  'quantity':
                      sel.contains(f['id']) ? '${n(cs[f['id']]!.text)}' : '0'
                }
            ]
          });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Morning stock')),
      bottomNavigationBar: !ok || fish.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                      onPressed: busy ? null : save,
                      child: Text(sel.isEmpty
                          ? 'Start with no stock'
                          : 'Confirm morning stock')))),
      body: !ok
          ? const Center(child: CircularProgressIndicator())
          : err != null
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24), child: Text(err!)))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  const Text(
                      "Check what you really have today. Yesterday's number is only a hint.",
                      style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 12),
                  if (fish.isEmpty)
                    const Panel(
                        child: Text('No fish added yet. Tap Add fish.')),
                  for (final id in sel)
                    Panel(
                        child: Column(children: [
                      Row(children: [
                        const Icon(Icons.set_meal, color: teal),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(nm(id),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17))),
                        IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => sel.remove(id))),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Expanded(
                            child: Tile('Yesterday closing', kg(prev[id]),
                                col: Colors.black54)),
                        SizedBox(
                            width: 130,
                            child: numField(cs[id]!, 'Today kg',
                                onChanged: (_) => setState(() {}))),
                      ]),
                    ])),
                  OutlinedButton.icon(
                      onPressed: add,
                      icon: const Icon(Icons.add),
                      label: const Text('Add fish')),
                  const SizedBox(height: 12),
                ]));
}
