import 'package:material_ui/material_ui.dart';
import 'core/api.dart';
import 'core/ui.dart';
import 'screens/auth_home.dart';
import 'screens/journal.dart';
import 'screens/accounts.dart';
import 'screens/more.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppS();
}

class _AppS extends State<App> {
  bool? ok;
  @override
  void initState() {
    super.initState();
    Api.onExpired = () => setState(() => ok = false);
    Api.hasSession().then((v) => setState(() => ok = v));
  }

  @override
  Widget build(BuildContext c) => MaterialApp(
      title: 'Fish Journal',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: ok == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : ok!
              ? Shell(onLogout: () async {
                  await Api.logout();
                  setState(() => ok = false);
                })
              : LoginPage(onDone: () => setState(() => ok = true)));
}

class Shell extends StatefulWidget {
  final VoidCallback onLogout;
  const Shell({super.key, required this.onLogout});
  @override
  State<Shell> createState() => _ShellS();
}

class _ShellS extends State<Shell> {
  int i = 0;
  @override
  Widget build(BuildContext c) {
    final pages = [
      HomePage(go: (n) => setState(() => i = n)),
      JournalPage(date: DateTime.now()),
      const AccountsPage(),
      const HistoryPage(),
      SettingsPage(onLogout: widget.onLogout)
    ];
    return Scaffold(
        body: SafeArea(child: pages[i]),
        bottomNavigationBar: NavigationBar(
            selectedIndex: i,
            onDestinationSelected: (n) => setState(() => i = n),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Journal'),
              NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: Icon(Icons.account_balance_wallet),
                  label: 'Accounts'),
              NavigationDestination(
                  icon: Icon(Icons.history), label: 'History'),
              NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings')
            ]));
  }
}
