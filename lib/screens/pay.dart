import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/ui.dart';

/// Payment from a hotel (received) or to a supplier (paid).
/// Shows a "payment saved" screen at the end. Done goes back to where the owner came from.
class PayScreen extends StatefulWidget {
  final bool hotel;
  final int? partyId;
  final Map? existing;
  const PayScreen(
      {super.key, required this.hotel, this.partyId, this.existing});
  @override
  State<PayScreen> createState() => _PS();
}

class _PS extends State<PayScreen> {
  List parties = [];
  int? p;
  String mode = 'cash';
  DateTime? dt;
  final a = TextEditingController();
  bool ready = false, busy = false;
  String? loadErr;
  Map? done;

  String get pk => widget.hotel ? 'hotel_id' : 'supplier_id';
  String get base =>
      widget.hotel ? '/api/v1/hotel-payments' : '/api/v1/supplier-payments';
  String get listPath =>
      widget.hotel ? '/api/v1/accounts/hotels' : '/api/v1/accounts/suppliers';
  String get who => widget.hotel ? 'hotel' : 'supplier';

  Map? get party {
    for (final x in parties) {
      if (x['id'] == p) return x as Map;
    }
    return null;
  }

  num get out => nz(party?['outstanding']);

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    try {
      parties = await fetch(listPath);
      parties
          .sort((x, y) => nz(y['outstanding']).compareTo(nz(x['outstanding'])));
      final ex = widget.existing;
      if (ex != null) {
        p = ex[pk] as int?;
        a.text = fmt(nz(ex['amount']));
        mode = '${ex['payment_mode']}' == 'upi' ? 'upi' : 'cash';
        dt = DateTime.tryParse('${ex['payment_date']}');
      } else {
        p = widget.partyId;
      }
      loadErr = null;
    } on ApiException catch (e) {
      loadErr = e.message;
    }
    if (mounted) setState(() => ready = true);
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context,
        initialDate: dt ?? now,
        firstDate: DateTime(now.year - 2),
        lastDate: now);
    if (d != null) setState(() => dt = d);
  }

  Future<void> save() async {
    final amt = n(a.text);
    if (p == null) {
      toast(context, 'Choose the $who');
      return;
    }
    if (amt <= 0) {
      toast(context, 'Type the amount');
      return;
    }
    if (widget.existing == null && amt > out + 0.001) {
      toast(context, 'More than pending ${inr(out)}. Cannot save.');
      return;
    }
    setState(() => busy = true);
    try {
      final body = <String, dynamic>{
        pk: p,
        'amount': fmt(amt),
        'payment_mode': mode,
        if (dt != null) 'payment_date': isoDate(dt!)
      };
      final ex = widget.existing;
      if (ex == null) {
        await Api.req('POST', base, body: body);
      } else {
        await Api.req('PUT', '$base/${ex['id']}', body: body);
      }
      final name = '${party?['name'] ?? ''}';
      var left = 0.0;
      try {
        final l = await fetch(listPath);
        for (final x in l) {
          if (x['id'] == p) left = nz(x['outstanding']).toDouble();
        }
      } catch (_) {}
      if (mounted)
        setState(() => done = {
              'name': name,
              'amount': amt,
              'mode': mode,
              'left': left,
              'date': dt == null ? 'Today' : niceDate(isoDate(dt!))
            });
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  Widget doneView() => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: tint(teal, 30), shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 56, color: teal)),
            const SizedBox(height: 20),
            const Text('Payment saved',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(inr(done!['amount']),
                style: const TextStyle(
                    fontSize: 36, fontWeight: FontWeight.w800, color: teal)),
            const SizedBox(height: 8),
            Text('${widget.hotel ? 'From' : 'To'} ${done!['name']}',
                style: const TextStyle(fontSize: 16)),
            Text('${'${done!['mode']}'.toUpperCase()} • ${done!['date']}',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            Panel(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                  Text(widget.hotel ? 'Hotel still owes' : 'You still owe'),
                  Text(inr(done!['left']),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 18))
                ])),
            const SizedBox(height: 8),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Done')),
          ])));

  Widget form() => ListView(padding: const EdgeInsets.all(16), children: [
        if (p == null) ...[
          Text(widget.hotel ? 'Which hotel paid?' : 'Which supplier?',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (parties.isEmpty)
            EmptyNote('No ${who}s yet. Add one in Settings.'),
          for (final x in parties)
            Panel(
                onTap: () => setState(() => p = x['id'] as int),
                child: Row(children: [
                  Expanded(
                      child: Text('${x['name']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 17))),
                  Text(
                      nz(x['outstanding']) > 0
                          ? inr(x['outstanding'])
                          : 'Clear',
                      style: TextStyle(
                          color:
                              nz(x['outstanding']) > 0 ? coral : Colors.black54,
                          fontWeight: FontWeight.w700)),
                ])),
        ] else ...[
          Panel(
              child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${party?['name'] ?? ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 20)),
                  Text(
                      widget.hotel
                          ? 'Owes you ${inr(out)}'
                          : 'You owe ${inr(out)}',
                      style: TextStyle(
                          color: out > 0 ? coral : Colors.black54,
                          fontWeight: FontWeight.w600)),
                ])),
            if (widget.existing == null && widget.partyId == null)
              TextButton(
                  onPressed: () => setState(() => p = null),
                  child: const Text('Change')),
          ])),
          numField(a, 'Amount (₹)',
              autofocus: true, onChanged: (_) => setState(() {})),
          if (out > 0 && widget.existing == null)
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                    onPressed: () => setState(() => a.text = fmt(out)),
                    child: Text('Full amount ${inr(out)}'))),
          const SizedBox(height: 8),
          SegmentedButton<String>(segments: const [
            ButtonSegment(
                value: 'cash', label: Text('Cash'), icon: Icon(Icons.payments)),
            ButtonSegment(
                value: 'upi', label: Text('UPI'), icon: Icon(Icons.qr_code))
          ], selected: {
            mode
          }, onSelectionChanged: (s) => setState(() => mode = s.first)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: pickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                  'Date: ${dt == null ? 'Today' : niceDate(isoDate(dt!))}')),
          if (widget.existing == null && n(a.text) > out + 0.001)
            const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                    'This is more than the pending amount. It cannot be saved.',
                    style:
                        TextStyle(color: coral, fontWeight: FontWeight.w600))),
        ],
      ]);

  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(
          title: Text(widget.existing != null
              ? 'Edit payment'
              : (widget.hotel ? 'Hotel paid' : 'Pay supplier'))),
      bottomNavigationBar: ready && done == null && p != null
          ? SafeArea(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                      onPressed: busy ? null : save,
                      child: Text(busy ? 'Saving' : 'Save payment'))))
          : null,
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : loadErr != null
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(loadErr!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: () {
                              setState(() => ready = false);
                              init();
                            },
                            child: const Text('Retry'))
                      ])))
              : done != null
                  ? doneView()
                  : form());
}
