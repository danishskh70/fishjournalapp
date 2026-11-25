import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api.dart';

const ocean = Color(0xFF0A2E4D),
    teal = Color(0xFF14B8A6),
    coral = Color(0xFFFF7A59);

ThemeData appTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
          seedColor: ocean, primary: ocean, secondary: teal),
      scaffoldBackgroundColor: const Color(0xFFF3F6FA),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)))),
    );

dynamic pick(dynamic m, List<String> ks) {
  if (m is Map) {
    for (final k in ks) {
      final v = m[k];
      if (v != null && v is! Map && v is! List) return v;
    }
    for (final v in m.values) {
      final r = pick(v, ks);
      if (r != null) return r;
    }
  }
  return null;
}

List asList(dynamic d) => d is List
    ? d
    : (d is Map
        ? ((d['items'] ??
            d['data'] ??
            d['results'] ??
            d['entries'] ??
            d['transactions'] ??
            []) as List)
        : []);
String inr(dynamic v) =>
    '₹${NumberFormat.decimalPattern('en_IN').format(num.tryParse('${v ?? 0}') ?? 0)}';
String kg(dynamic v) => '${num.tryParse('${v ?? 0}') ?? 0} kg';
String niceDate(String? s) {
  final d = DateTime.tryParse(s ?? '');
  return d == null ? (s ?? '') : DateFormat('d MMM yyyy').format(d);
}

String label(String k) {
  final s = k.replaceAll('_', ' ');
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(
    SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
Future<bool> confirm(BuildContext c, String m) async =>
    await showDialog<bool>(
        context: c,
        builder: (_) => AlertDialog(content: Text(m), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancel')),
              FilledButton(
                  style:
                      FilledButton.styleFrom(minimumSize: const Size(100, 44)),
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Confirm'))
            ])) ??
    false;
Future<T?> sheet<T>(BuildContext c, Widget w) => showModalBottomSheet<T>(
    context: c,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFF3F6FA),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: w)));

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets pad;
  final VoidCallback? onTap;
  const Panel(
      {super.key,
      required this.child,
      this.pad = const EdgeInsets.all(16),
      this.onTap});
  @override
  Widget build(BuildContext c) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          elevation: 0.5,
          shadowColor: Colors.black26,
          child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(padding: pad, child: child))));
}

class Grad extends StatelessWidget {
  final Widget child;
  const Grad({super.key, required this.child});
  @override
  Widget build(BuildContext c) => Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
              colors: [ocean, Color(0xFF0E6E7E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          boxShadow: const [
            BoxShadow(
                color: Color(0x330A2E4D), blurRadius: 18, offset: Offset(0, 8))
          ]),
      child: child);
}

class KV extends StatelessWidget {
  final Map m;
  const KV(this.m, {super.key});
  @override
  Widget build(BuildContext c) => Column(children: [
        for (final e in m.entries.where(
            (e) => e.value != null && e.value is! Map && e.value is! List))
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(
                    child: Text(label(e.key),
                        style: const TextStyle(color: Colors.black54))),
                Text('${e.value}',
                    style: const TextStyle(fontWeight: FontWeight.w600))
              ]))
      ]);
}

class Fut extends StatefulWidget {
  final Future<dynamic> Function() load;
  final Widget Function(BuildContext, dynamic, VoidCallback) build;
  const Fut({super.key, required this.load, required this.build});
  @override
  State<Fut> createState() => _FutS();
}

class _FutS extends State<Fut> {
  late Future<dynamic> f = widget.load();
  void re() => setState(() => f = widget.load());
  @override
  Widget build(BuildContext c) => FutureBuilder(
      future: f,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (s.hasError)
          return Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.cloud_off,
                        size: 48, color: Colors.black38),
                    const SizedBox(height: 12),
                    Text('${s.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: re, child: const Text('Retry'))
                  ])));
        return widget.build(c, s.data, re);
      });
}

Widget numField(TextEditingController c, String l,
        {void Function(String)? onChanged}) =>
    TextField(
        controller: c,
        onChanged: onChanged,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: l));
Future<List> fetch(String p, {Map<String, String>? q}) async =>
    asList(await Api.req('GET', p, q: q));
Widget drop(String l, int? v, List items, void Function(int?) on) =>
    DropdownButtonFormField<int>(
        value: items.any((e) => e['id'] == v) ? v : null,
        decoration: InputDecoration(labelText: l),
        items: [
          for (final e in items)
            DropdownMenuItem<int>(
                value: e['id'] as int, child: Text('${e['name']}'))
        ],
        onChanged: on);

class Mini extends StatelessWidget {
  final String l, v;
  final Color col;
  const Mini(this.l, this.v, {super.key, this.col = ocean});
  @override
  Widget build(BuildContext c) => Expanded(
      child: Container(
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: col.withOpacity(.08),
              borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l,
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 2),
            Text(v, style: TextStyle(fontWeight: FontWeight.w800, color: col))
          ])));
}

dynamic fuzzy(dynamic m, List<String> t) {
  if (m is Map) {
    for (final e in m.entries) {
      final k = '${e.key}'.toLowerCase();
      if (e.value != null &&
          e.value is! Map &&
          e.value is! List &&
          t.every(k.contains)) return e.value;
    }
    for (final v in m.values) {
      final r = fuzzy(v, t);
      if (r != null) return r;
    }
  }
  return null;
}

Map<String, List> fishLists(dynamic m, [String k = '', Map<String, List>? o]) {
  o ??= {};
  if (m is List) {
    if (m.isNotEmpty &&
        m.first is Map &&
        (m.first as Map).containsKey('fish_id')) {
      o[k] = m;
    } else {
      for (final x in m) {
        fishLists(x, k, o);
      }
    }
  } else if (m is Map) {
    m.forEach((kk, v) => fishLists(v, '$kk'.toLowerCase(), o));
  }
  return o;
}

Map<int, String>? _fn;
Future<Map<int, String>> fishNames() async {
  _fn ??= {
    for (final f
        in await fetch('/api/v1/fish', q: {'include_inactive': 'true'}))
      f['id'] as int: '${f['name']}'
  };
  return _fn!;
}

class Tile extends StatelessWidget {
  final String l, v;
  final Color col;
  const Tile(this.l, this.v, {super.key, this.col = ocean});
  @override
  Widget build(BuildContext c) => Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: col.withOpacity(.08), borderRadius: BorderRadius.circular(12)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l,
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
            Text(v, style: TextStyle(fontWeight: FontWeight.w800, color: col))
          ]));
}

class Inner extends StatelessWidget {
  final Widget child;
  const Inner(this.child, {super.key});
  @override
  Widget build(BuildContext c) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF3F6FA),
          borderRadius: BorderRadius.circular(16)),
      child: child);
}
