import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/jobs.dart';
import '../core/ui.dart';

/// End of day on ONE screen: fish left, then cash and UPI. Blank is never zero.
/// Pops true when the day is closed.
class CloseScreen extends StatefulWidget {
  final Map j;
  const CloseScreen({super.key, required this.j});
  @override
  State<CloseScreen> createState() => _CL();
}

class _CL extends State<CloseScreen> {
  List fish = [];
  final cs = <int, TextEditingController>{};
  final cash = TextEditingController(), upi = TextEditingController();
  late final List rows = L(M(widget.j['stock'])['rows']).where((r) => nz(r['opening_quantity']) > 0 || nz(r['purchased']) > 0).toList();
  bool tried = false, busy = false;

  @override
  void initState() {
    super.initState();
    for (final r in rows) {
      cs[r['fish_id'] as int] = TextEditingController();
    }
    fetch('/api/v1/fish').then((l) {
      if (mounted) setState(() => fish = l);
    }).catchError((_) {});
  }

  Map<String, dynamic> body() {
    final ids = <int>{...cs.keys};
    for (final f in fish) {
      ids.add(f['id'] as int);
    }
    return {
      'stocks': [for (final id in ids) {'fish_id': id, 'quantity': cs.containsKey(id) ? '${n(cs[id]!.text)}' : '0'}],
      'cash_amount': '${n(cash.text)}',
      'upi_amount': '${n(upi.text)}',
    };
  }

  bool filled() => cs.values.every((c) => isNum(c.text)) && isNum(cash.text) && isNum(upi.text);

  Future<void> check() async {
    if (Jobs.i.list.isNotEmpty) {
      toast(context, 'Wait. Some entries are not saved yet. See Home.');
      return;
    }
    setState(() => tried = true);
    if (!filled()) {
      toast(context, 'Fill every box. Type 0 if none.');
      return;
    }
    setState(() => busy = true);
    Map? r;
    try {
      r = await Api.req('POST', '/api/v1/journals/${widget.j['id']}/close-preview', body: body()) as Map;
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => busy = false);
    if (r == null || !mounted) return;
    final go = await sheet<bool>(context, PreviewView(r: r));
    if (go == true && mounted) await close();
  }

  Future<void> close() async {
    setState(() => busy = true);
    try {
      await Api.req('POST', '/api/v1/journals/${widget.j['id']}/close', body: body());
      if (mounted) Navigator.pop(context, true);
      return;
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  void zeroAll() {
    for (final c in cs.values) {
      if (c.text.trim().isEmpty) c.text = '0';
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('End of Day')),
      bottomNavigationBar: SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton(style: FilledButton.styleFrom(backgroundColor: coral), onPressed: busy ? null : check, child: Text(busy ? 'Please wait' : 'Check and End Day')))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Sect('1. Fish left in shop (kg)', Icons.inventory_2, teal),
          if (rows.isEmpty) const EmptyNote('No fish today.'),
          for (final r in rows)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: numField(cs[r['fish_id'] as int]!, '${r['fish_name']}',
                    helper: 'Had ${qty(r['available'])} kg • Hotels took ${qty(r['hotel_sold'])} kg',
                    error: tried && !isNum(cs[r['fish_id'] as int]!.text) ? 'Type 0 if none' : null,
                    onChanged: (_) => setState(() {}))),
          if (rows.isNotEmpty) TextButton(onPressed: zeroAll, child: const Text('Nothing left. Fill empty boxes with 0')),
        ])),
        Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Sect('2. Total money today', Icons.payments, ocean),
          numField(cash, 'Total cash (₹)', error: tried && !isNum(cash.text) ? 'Type 0 if none' : null, onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          numField(upi, 'Total UPI (₹)', error: tried && !isNum(upi.text) ? 'Type 0 if none' : null, onChanged: (_) => setState(() {})),
        ])),
        const SizedBox(height: 60),
      ]));
}

class PreviewView extends StatelessWidget {
  final Map r;
  const PreviewView({super.key, required this.r});
  @override
  Widget build(BuildContext c) {
    final can = r['can_close'] == true;
    final nc = L(r['sales_normal_customer']);
    final m = M(r['money']);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(can ? 'Ready to close' : 'Cannot close yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: can ? teal : coral)),
      const SizedBox(height: 10),
      for (final p in L(r['problems'])) Inner(Text('$p', style: const TextStyle(color: coral))),
      if (nc.isNotEmpty) ...[
        const Sect('Walk-in customers took', Icons.people, ocean),
        tbl(['Fish', 'Kg'], [for (final e in nc) ['${e['fish_name']}', qty(e['quantity'])]], foot: ['Total', qty(sum(nc, 'quantity'))], flex: [3, 1]),
        const SizedBox(height: 12),
      ],
      if (m.isNotEmpty) Row(children: [Mini('Cash', inr(m['cash_amount'])), Mini('UPI', inr(m['upi_amount'])), Mini('Total', inr(m['total']), col: teal)]),
      const SizedBox(height: 16),
      if (can) FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm and Close Business')),
      if (!can) FilledButton(onPressed: () => Navigator.pop(c, false), child: const Text('Go back and fix')),
      if (can) TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Go back')),
    ]);
  }
}
