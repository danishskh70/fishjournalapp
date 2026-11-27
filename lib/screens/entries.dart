import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/jobs.dart';
import '../core/ui.dart';
import 'pay.dart';
import '../core/result.dart';

/// Today's entries with edit and delete (only while the day is open).
class TodayEntries extends StatefulWidget {
  final String date;
  const TodayEntries({super.key, required this.date});
  @override
  State<TodayEntries> createState() => _TE();
}

class _TE extends State<TodayEntries> {
  int v = 0;

  @override
  void initState() {
    super.initState();
    Jobs.i.tick.addListener(_tick);
  }

  @override
  void dispose() {
    Jobs.i.tick.removeListener(_tick);
    super.dispose();
  }

  void _tick() {
    if (mounted) setState(() => v++);
  }

  Future<void> del(String path, Map e, String what) async {
    if (!await confirm(context, 'Delete this $what?')) return;

    final deleted = await runWithResult(
      context,
      action: () => Api.req('DELETE', '$path/${e['id']}'),
      working: 'Deleting $what...',
      okTitle: '${what[0].toUpperCase()}${what.substring(1)} deleted',
      retryable: false,
      failHint: 'Check the entries list before trying this deletion again.',
    );

    if (deleted && mounted) setState(() => v++);
  }

  Future<void> editPurchase(Map e) async {
    final ok = await sheet<bool>(context, EditPurchase(e: e));
    if (ok == true && mounted) setState(() => v++);
  }

  Future<void> editSale(Map e) async {
    final ok = await sheet<bool>(context, EditSale(e: e));
    if (ok == true && mounted) setState(() => v++);
  }

  Future<void> editPay(bool hotel, Map e) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PayScreen(hotel: hotel, existing: e)));
    if (mounted) setState(() => v++);
  }

  Widget row(
          Widget info, bool closed, VoidCallback edit, VoidCallback delete) =>
      Inner(Row(children: [
        Expanded(child: info),
        if (!closed)
          PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (a) {
                if (a == 'edit') {
                  edit();
                } else {
                  delete();
                }
              },
              itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Update')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ]),
      ]));

  Widget sect(String t, IconData i, Color col, List<Widget> kids) => Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Sect(t, i, col),
        if (kids.isEmpty) const EmptyNote('Nothing yet'),
        ...kids,
      ]));

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: const Text('Entries')),
      body: Fut(
          key: ValueKey(v),
          cacheKey: 'journal:${widget.date}',
          load: () => Api.req('GET', '/api/v1/journals/by-date/${widget.date}'),
          build: (c, x, re) {
            final j = x as Map;
            final closed = '${j['status']}' == 'closed';
            final pur = L(M(j['purchases'])['entries']);
            final sal = L(M(j['sales'])['hotel_sales']);
            final hp = L(M(j['hotel_info'])['payments_received']);
            final sp = L(M(j['supplier_info'])['later_payments']);
            return ListView(padding: const EdgeInsets.all(16), children: [
              const JobTray(),
              if (closed)
                const Panel(
                    child:
                        Text('This day is closed. Entries cannot be changed.')),
              sect('Purchases', Icons.shopping_basket, coral, [
                for (final e in pur)
                  row(
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${e['supplier_name']} • ${e['fish_name']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            Text(
                                '${qty(e['quantity'])} kg × ${inr(e['rate'])} = ${inr(e['amount'])}'),
                            Text(
                                'Paid ${inr(e['paid_now'])} • Pending ${inr(e['due_created'])}',
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 12)),
                          ]),
                      closed,
                      () => editPurchase(e as Map),
                      () => del('/api/v1/purchases', e as Map, 'purchase')),
              ]),
              sect('Hotel sales', Icons.storefront, teal, [
                for (final e in sal)
                  row(
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${e['hotel_name']} • ${e['fish_name']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            Text(
                                '${qty(e['quantity'])} kg × ${inr(e['rate'])} = ${inr(e['amount'])}'),
                          ]),
                      closed,
                      () => editSale(e as Map),
                      () => del('/api/v1/hotel-sales', e as Map, 'sale')),
              ]),
              sect('Received from hotels today', Icons.south_west, teal, [
                for (final e in hp)
                  row(
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${e['hotel_name']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            Text(
                                '${inr(e['amount'])} • ${'${e['payment_mode']}'.toUpperCase()}'),
                          ]),
                      closed,
                      () => editPay(true, e as Map),
                      () => del('/api/v1/hotel-payments', e as Map, 'payment')),
              ]),
              sect('Paid to suppliers today', Icons.north_east, coral, [
                for (final e in sp)
                  row(
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${e['supplier_name']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            Text(
                                '${inr(e['amount'])} • ${'${e['payment_mode']}'.toUpperCase()}'),
                          ]),
                      closed,
                      () => editPay(false, e as Map),
                      () => del(
                          '/api/v1/supplier-payments', e as Map, 'payment')),
              ]),
            ]);
          }));
}

class EditPurchase extends StatefulWidget {
  final Map e;
  const EditPurchase({super.key, required this.e});
  @override
  State<EditPurchase> createState() => _EP();
}

class _EP extends State<EditPurchase> {
  late final q = TextEditingController(text: qty(widget.e['quantity']));
  late final r = TextEditingController(text: fmt(nz(widget.e['rate'])));
  late final p = TextEditingController(text: fmt(nz(widget.e['paid_now'])));
  late String mode = '${widget.e['payment_mode']}' == 'upi' ? 'upi' : 'cash';
  bool busy = false;

  Future<void> save() async {
    final amount = r2(n(q.text) * n(r.text));

    if (n(q.text) <= 0 || n(r.text) <= 0) {
      toast(context, 'Type kg and rate');
      return;
    }

    if (n(p.text) < 0 || n(p.text) > amount + 0.001) {
      toast(context, 'Paid cannot be more than ₹${fmt(amount)}');
      return;
    }

    final saved = await runWithResult(
      context,
      action: () => Api.req(
        'PUT',
        '/api/v1/purchases/${widget.e['id']}',
        body: {
          'supplier_id': widget.e['supplier_id'],
          'fish_id': widget.e['fish_id'],
          'quantity': '${n(q.text)}',
          'rate': '${n(r.text)}',
          'paid_now': '${n(p.text)}',
          if (n(p.text) > 0) 'payment_mode': mode,
        },
      ),
      working: 'Updating purchase...',
      okTitle: 'Purchase updated',
      retryable: true,
    );

    if (saved && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext c) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${widget.e['supplier_name']} • ${widget.e['fish_name']}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        numField(q, 'Quantity (kg)'),
        const SizedBox(height: 12),
        numField(r, 'Rate per kg (₹)'),
        const SizedBox(height: 12),
        numField(p, 'Paid now (₹)'),
        const SizedBox(height: 12),
        SegmentedButton<String>(segments: const [
          ButtonSegment(
              value: 'cash', label: Text('Cash'), icon: Icon(Icons.payments)),
          ButtonSegment(
              value: 'upi', label: Text('UPI'), icon: Icon(Icons.qr_code))
        ], selected: {
          mode
        }, onSelectionChanged: (s) => setState(() => mode = s.first)),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: busy ? null : save, child: const Text('Save changes')),
      ]);
}

class EditSale extends StatefulWidget {
  final Map e;
  const EditSale({super.key, required this.e});
  @override
  State<EditSale> createState() => _ES();
}

class _ES extends State<EditSale> {
  late final q = TextEditingController(text: qty(widget.e['quantity']));
  late final r = TextEditingController(text: fmt(nz(widget.e['rate'])));

  Future<void> save() async {
    if (n(q.text) <= 0 || n(r.text) <= 0) {
      toast(context, 'Type kg and rate');
      return;
    }

    final saved = await runWithResult(
      context,
      action: () => Api.req(
        'PUT',
        '/api/v1/hotel-sales/${widget.e['id']}',
        body: {
          'hotel_id': widget.e['hotel_id'],
          'fish_id': widget.e['fish_id'],
          'quantity': '${n(q.text)}',
          'rate': '${n(r.text)}',
        },
      ),
      working: 'Updating sale...',
      okTitle: 'Sale updated',
      retryable: true,
    );

    if (saved && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext c) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${widget.e['hotel_name']} • ${widget.e['fish_name']}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        numField(q, 'Quantity (kg)'),
        const SizedBox(height: 12),
        numField(r, 'Rate per kg (₹)'),
        const SizedBox(height: 16),
        FilledButton(onPressed: save, child: const Text('Save changes')),
      ]);
}
