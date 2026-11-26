import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'api.dart';
import 'cache.dart';

const ocean = Color(0xFF0A2E4D),
    teal = Color(0xFF0F766E),
    coral = Color(0xFFC2410C),
    deep = Color(0xFF0E6E7E),
    paper = Color(0xFFF3F6FA);

final msgKey = GlobalKey<ScaffoldMessengerState>();
final shellTab = ValueNotifier<int>(0);
final accTab = ValueNotifier<int>(0);

Color tint(Color c, [int a = 22]) => c.withAlpha(a);

ThemeData appTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
          seedColor: ocean, primary: ocean, secondary: teal),
      scaffoldBackgroundColor: paper,
      appBarTheme: const AppBarTheme(
          backgroundColor: paper, surfaceTintColor: Colors.transparent),
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
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)))),
    );

// ---------- number and text helpers ----------
num nz(dynamic v) => v is num ? v : (num.tryParse('${v ?? 0}') ?? 0);
num n(String s) => num.tryParse(s.trim()) ?? 0;
bool isNum(String s) => num.tryParse(s.trim()) != null;
num r2(num x) => (x * 100).roundToDouble() / 100;
String fmt(num x) {
  final y = r2(x);
  return y == y.roundToDouble() ? y.toInt().toString() : y.toString();
}

String inr(dynamic v) {
  final x = nz(v);
  final s = NumberFormat.decimalPattern('en_IN').format(x.abs());
  return '${x < 0 ? '-' : ''}₹$s';
}

String qty(dynamic v) => fmt(nz(v));
String kg(dynamic v) => '${qty(v)} kg';
String niceDate(String? s) {
  final d = DateTime.tryParse(s ?? '');
  return d == null ? (s ?? '') : DateFormat('d MMM yyyy').format(d);
}

String shortDate(String? s) {
  final d = DateTime.tryParse(s ?? '');
  return d == null ? (s ?? '') : DateFormat('EEE d MMM').format(d);
}

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String label(String k) {
  final s = k.replaceAll('_', ' ');
  return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

List L(dynamic x) => x is List ? x : [];
Map M(dynamic x) => x is Map ? x : {};
num sum(List es, String k) => es.fold<num>(0, (a, e) => a + nz(e[k]));
List asList(dynamic d) => d is List
    ? d
    : (d is Map
        ? ((d['items'] ?? d['data'] ?? d['results'] ?? d['entries'] ?? [])
            as List)
        : []);
Future<List> fetch(String p, {Map<String, String>? q}) async =>
    asList(await Api.req('GET', p, q: q));

// ---------- messages ----------
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
    backgroundColor: paper,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: w)));

// ---------- widgets ----------
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
              colors: [ocean, deep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          boxShadow: const [
            BoxShadow(
                color: Color(0x330A2E4D), blurRadius: 18, offset: Offset(0, 8))
          ]),
      child: child);
}

class BigTile extends StatelessWidget {
  final String t, s;
  final IconData i;
  final Color col;
  final VoidCallback on;
  const BigTile(this.t, this.s, this.i, this.col, this.on, {super.key});
  @override
  Widget build(BuildContext c) => Material(
      color: col,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: on,
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(i, color: Colors.white, size: 40),
                    const SizedBox(height: 22),
                    Text(t,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 20)),
                    const SizedBox(height: 2),
                    Text(s,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12))
                  ]))));
}

class Sect extends StatelessWidget {
  final String t;
  final IconData i;
  final Color col;
  const Sect(this.t, this.i, this.col, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(i, color: col, size: 20),
        const SizedBox(width: 8),
        Text(t,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))
      ]));
}

class EmptyNote extends StatelessWidget {
  final String t;
  const EmptyNote(this.t, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(t, style: const TextStyle(color: Colors.black54)));
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
          color: tint(col, 20), borderRadius: BorderRadius.circular(12)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            Text(v, style: TextStyle(fontWeight: FontWeight.w800, color: col))
          ]));
}

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
              color: tint(col, 20), borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 2),
            Text(v, style: TextStyle(fontWeight: FontWeight.w800, color: col))
          ])));
}

class Inner extends StatelessWidget {
  final Widget child;
  const Inner(this.child, {super.key});
  @override
  Widget build(BuildContext c) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: paper, borderRadius: BorderRadius.circular(16)),
      child: child);
}

class Fut extends StatefulWidget {
  final Future<dynamic> Function() load;
  final Widget Function(BuildContext, dynamic, Future<void> Function()) build;
  final String? cacheKey;

  const Fut({
    super.key,
    required this.load,
    required this.build,
    this.cacheKey,
  });

  @override
  State<Fut> createState() => _FutS();
}

class _FutS extends State<Fut> {
  late Future<dynamic> f;

  @override
  void initState() {
    super.initState();
    f = _initialLoad();
    DataCache.i.addListener(_onCacheChanged);
  }

  Future<dynamic> _initialLoad() {
    final key = widget.cacheKey;
    return key == null ? widget.load() : DataCache.i.cached(key, widget.load);
  }

  void _onCacheChanged() {
    final key = widget.cacheKey;

    if (!mounted || key == null || !DataCache.i.has(key)) return;

    if (DataCache.i.isStale(key)) {
      unawaited(
        DataCache.i.cached(key, widget.load).then<void>(
              (_) {},
              onError: (Object error, StackTrace stack) {},
            ),
      );
    }

    setState(() {});
  }

  Future<void> re() {
    final key = widget.cacheKey;
    final fut =
        key == null ? widget.load() : DataCache.i.load(key, widget.load);
    setState(() => f = fut);
    return fut.then<void>((_) {}, onError: (_) {});
  }

  @override
  void didUpdateWidget(covariant Fut oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.cacheKey != widget.cacheKey) {
      f = _initialLoad();
    }
  }

  @override
  void dispose() {
    DataCache.i.removeListener(_onCacheChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final key = widget.cacheKey;

    if (key != null && DataCache.i.has(key)) {
      return widget.build(c, DataCache.i.peek(key), re);
    }

    return FutureBuilder(
      future: f,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        if (s.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off,
                    size: 48,
                    color: Colors.black38,
                  ),
                  const SizedBox(height: 12),
                  Text('${s.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: re,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return widget.build(c, s.data, re);
      },
    );
  }
}

Widget numField(TextEditingController c, String l,
        {void Function(String)? onChanged,
        String? helper,
        String? error,
        bool autofocus = false,
        Key? k}) =>
    TextField(
        key: k,
        controller: c,
        onChanged: onChanged,
        autofocus: autofocus,
        textInputAction: TextInputAction.next,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
            labelText: l, helperText: helper, errorText: error));

/// Simple table: header, rows, optional bold total row. Column 0 left, others right.
Widget tbl(List<String> head, List<List<String>> rows,
    {List<String>? foot, List<int>? flex}) {
  final f = flex ?? List<int>.filled(head.length, 1);
  final Map<int, TableColumnWidth> cw = {
    for (var i = 0; i < head.length; i++) i: FlexColumnWidth(f[i].toDouble())
  };
  TableRow row(List<String> cells, {bool bold = false, Color? bgc}) => TableRow(
          decoration: bgc == null ? null : BoxDecoration(color: bgc),
          children: [
            for (var i = 0; i < cells.length; i++)
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                  child: Text(cells[i],
                      textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              bold ? FontWeight.w800 : FontWeight.w500)))
          ]);
  return Table(columnWidths: cw, children: [
    row(head, bold: true, bgc: tint(ocean, 18)),
    for (final r in rows) row(r),
    if (foot != null) row(foot, bold: true, bgc: tint(teal, 30)),
  ]);
}

Future<Map?> newFishDialog(BuildContext c) async {
  final t = TextEditingController();
  final ok = await showDialog<bool>(
      context: c,
      builder: (_) => AlertDialog(
              title: const Text('New fish'),
              content: TextField(
                  controller: t,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Fish name')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Cancel')),
                FilledButton(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(100, 44)),
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Add'))
              ]));
  if (ok != true || t.text.trim().isEmpty) return null;
  try {
    final r =
        await Api.req('POST', '/api/v1/fish', body: {'name': t.text.trim()});
    return r as Map;
  } on ApiException catch (e) {
    if (c.mounted) toast(c, e.message);
    return null;
  }
}
