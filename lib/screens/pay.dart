import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/ui.dart';
import '../core/result.dart';

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
  bool ready = false;
  String? loadErr;

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

    final body = <String, dynamic>{
      pk: p,
      'amount': fmt(amt),
      'payment_mode': mode,
      if (dt != null) 'payment_date': isoDate(dt!),
    };

    final ex = widget.existing;
    final name = '${party?['name'] ?? ''}';
    final paymentDate = dt == null ? 'Today' : niceDate(isoDate(dt!));

    final saved = await runWithResult(
      context,
      action: () async {
        if (ex == null) {
          await Api.req('POST', base, body: body);
        } else {
          await Api.req('PUT', '$base/${ex['id']}', body: body);
        }

        var left = 0.0;
        try {
          final l = await fetch(listPath);
          for (final x in l) {
            if (x['id'] == p) {
              left = nz(x['outstanding']).toDouble();
            }
          }
        } catch (_) {}

        return {
          'name': name,
          'amount': amt,
          'mode': mode,
          'left': left,
          'date': paymentDate,
        };
      },
      working: ex == null ? 'Saving payment...' : 'Updating payment...',
      okTitle: ex == null ? 'Payment saved' : 'Payment updated',
      autoClose: false,
      retryable: ex != null,
      failHint: ex == null
          ? 'Do not record this payment again yet. Check the payment ledger first. If it is already there, do not save it again.'
          : null,
      okLines: (result) {
        final d = result as Map;
        return [
          inr(d['amount']),
          '${widget.hotel ? 'From' : 'To'} ${d['name']}',
          '${'${d['mode']}'.toUpperCase()} • ${d['date']}',
          widget.hotel
              ? 'Hotel still owes ${inr(d['left'])}'
              : 'You still owe ${inr(d['left'])}',
        ];
      },
    );

    if (saved && mounted) {
      Navigator.pop(context, true);
    }
  }

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
      bottomNavigationBar: ready && p != null
          ? SafeArea(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                      onPressed: save, child: const Text('Save payment'))))
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
              : form());
}
