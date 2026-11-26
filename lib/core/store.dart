import 'package:shared_preferences/shared_preferences.dart';

class Store {
  static SharedPreferences? _p;
  static Future<SharedPreferences> _prefs() async {
    _p ??= await SharedPreferences.getInstance();
    return _p!;
  }

  static Future<String?> get(String k) async {
    final p = await _prefs();
    return p.getString(k);
  }

  static Future<void> set(String k, String v) async {
    final p = await _prefs();
    await p.setString(k, v);
  }

  static Future<void> del(String k) async {
    final p = await _prefs();
    await p.remove(k);
  }
}
