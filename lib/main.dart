import 'package:flutter/material.dart';
import 'core/api.dart';
import 'core/jobs.dart';
import 'core/page_physics.dart';
import 'core/ui.dart';
import 'core/update.dart';
import 'screens/accounts.dart';
import 'screens/auth.dart';
import 'screens/history.dart';
import 'screens/home.dart';
import 'screens/settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Api.ping();
  runApp(const App());
}

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

    Api.onExpired = () {
      if (mounted) setState(() => ok = false);
    };

    Api.hasSession().then((v) {
      if (mounted) setState(() => ok = v);
    });
  }

  @override
  Widget build(BuildContext c) => MaterialApp(
        title: 'Fish Khata',
        scaffoldMessengerKey: msgKey,
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: ok == null
            ? const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              )
            : ok!
                ? Shell(
                    onLogout: () async {
                      await Api.logout();
                      if (mounted) setState(() => ok = false);
                    },
                  )
                : LoginPage(
                    onDone: () => setState(() => ok = true),
                  ),
      );
}

class KeepPage extends StatefulWidget {
  final Widget child;

  const KeepPage({super.key, required this.child});

  @override
  State<KeepPage> createState() => _KeepPageS();
}

class _KeepPageS extends State<KeepPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class Shell extends StatefulWidget {
  final VoidCallback onLogout;

  const Shell({super.key, required this.onLogout});

  @override
  State<Shell> createState() => _ShellS();
}

class _ShellS extends State<Shell> {
  late final PageController _pageController;
  late final List<Widget> _pages;

  static const _pageDuration = Duration(milliseconds: 450);
  static const _pageCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();

    shellTab.value = 0;

    _pageController = PageController(initialPage: 0);
    shellTab.addListener(_onTabChanged);

    _pages = [
      const KeepPage(child: HomePage()),
      const KeepPage(child: AccountsPage()),
      const KeepPage(child: HistoryPage()),
      KeepPage(child: SettingsPage(onLogout: widget.onLogout)),
    ];

    Jobs.i.init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Updates.onLaunch(context);
    });
  }

  void _onTabChanged() {
    if (!_pageController.hasClients) return;

    final target = shellTab.value;
    final current =
        _pageController.page ?? _pageController.initialPage.toDouble();

    if (current.round() == target) return;

    _pageController.animateToPage(
      target,
      duration: _pageDuration,
      curve: _pageCurve,
    );
  }

  void _onPageChanged(int index) {
    if (shellTab.value != index) {
      shellTab.value = index;
    }
  }

  @override
  void dispose() {
    shellTab.removeListener(_onTabChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => ValueListenableBuilder<int>(
        valueListenable: shellTab,
        builder: (c, i, _) => Scaffold(
          body: SafeArea(
            child: PageView.custom(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const OnePageScrollPhysics(),
              childrenDelegate: SliverChildListDelegate(_pages),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: i,
            onDestinationSelected: (n) {
              shellTab.value = n;
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: 'Accounts',
              ),
              NavigationDestination(
                icon: Icon(Icons.history),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      );
}
