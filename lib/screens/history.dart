import 'package:flutter/material.dart';
import '../core/ui.dart';
import 'sheet.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('History', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Tap a day to see the full sheet.', style: TextStyle(color: Colors.black54))),
        Expanded(
            child: Fut(
                load: () => fetch('/api/v1/history', q: {'limit': '90', 'offset': '0'}),
                build: (c, data, re) {
                  final l = data as List;
                  if (l.isEmpty) return const Center(child: Text('No days yet.'));
                  String lastMonth = '';
                  final kids = <Widget>[];
                  for (final h in l) {
                    final d = '${h['business_date']}';
                    final month = d.length >= 7 ? d.substring(0, 7) : d;
                    if (month != lastMonth) {
                      lastMonth = month;
                      kids.add(Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 8), child: Text(_monthName(d), style: const TextStyle(fontWeight: FontWeight.w800, color: ocean))));
                    }
                    final closed = '${h['status']}' == 'closed';
                    kids.add(Panel(
                        onTap: () async {
                          await Navigator.push(c, MaterialPageRoute(builder: (_) => DaySheet(date: d)));
                          re();
                        },
                        child: Row(children: [
                          Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(shortDate(d), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            Text(closed ? 'Cash ${inr(h['cash_amount'])} • UPI ${inr(h['upi_amount'])}' : 'Not closed', style: TextStyle(color: closed ? Colors.black54 : coral, fontWeight: closed ? FontWeight.w400 : FontWeight.w700)),
                          ])),
                          if (closed) Text(inr(h['total_money']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const Icon(Icons.chevron_right),
                        ])));
                  }
                  return RefreshIndicator(onRefresh: () async => re(), child: ListView(padding: const EdgeInsets.all(16), children: kids));
                }))
      ]);

  static String _monthName(String d) {
    final x = DateTime.tryParse(d);
    if (x == null) return d;
    const m = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${m[x.month - 1]} ${x.year}';
  }
}
