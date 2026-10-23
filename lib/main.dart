import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Psr3App());
}

const psBlue = Color(0xFF0667D8);
const psBlueDark = Color(0xFF003A8C);
const pageBg = Color(0xFFF5F7FB);
const ink = Color(0xFF151A22);
const muted = Color(0xFF6D7480);

class GameItem {
  final String id;
  final String title;
  final String cover;

  const GameItem(this.id, this.title, this.cover);
}

const games = <GameItem>[
  GameItem('fortnite', 'Fortnite', 'assets/covers/fortnite.svg'),
  GameItem('creature', 'Creature', 'assets/covers/creature.svg'),
  GameItem('mp3dtest', 'MP3Dtest', 'assets/covers/mp3dtest.svg'),
  GameItem('minecraft_beta', 'Minecraft Beta', 'assets/covers/minecraft_beta.svg'),
  GameItem('terraria', 'Terraria', 'assets/covers/terraria.svg'),
  GameItem('gta_beta', 'GTA beta', 'assets/covers/gta_beta.svg'),
];

class Psr3App extends StatelessWidget {
  const Psr3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PSR3',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: psBlue,
          brightness: Brightness.light,
        ),
        fontFamily: 'ZenMaru',
      ),
      home: const RootPage(),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  final AudioPlayer audio = AudioPlayer();
  final Set<String> installed = <String>{};
  final Map<String, double> progress = <String, double>{};

  bool loading = true;
  bool signedIn = false;
  int tab = 0;

  @override
  void initState() {
    super.initState();
    loadState();
  }

  @override
  void dispose() {
    unawaited(audio.dispose());
    super.dispose();
  }

  Future<void> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('installed_games') ?? const <String>[];
    if (!mounted) return;
    setState(() {
      installed.addAll(saved);
      signedIn = prefs.getBool('signed_in') ?? false;
      loading = false;
    });
  }

  Future<void> saveInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('installed_games', installed.toList());
  }

  Future<void> playSound(String path) async {
    try {
      await audio.stop();
      await audio.setReleaseMode(ReleaseMode.stop);
      await audio.play(AssetSource(path));
    } catch (_) {}
  }

  Future<void> showError(String message) async {
    unawaited(playSound('audio/error.mp3'));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> signIn(String login, String password) async {
    if (login.trim().isEmpty || password.trim().isEmpty) {
      await showError('Введите логин и пароль');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('signed_in', true);
    if (!mounted) return;
    setState(() => signedIn = true);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('signed_in', false);
    if (!mounted) return;
    setState(() {
      signedIn = false;
      tab = 0;
    });
  }

  Future<void> installGame(GameItem game) async {
    if (installed.contains(game.id)) {
      setState(() => tab = 2);
      return;
    }
    if (progress.containsKey(game.id)) {
      await showError('Установка уже идёт');
      return;
    }

    await playSound('audio/install.mp3');
    if (!mounted) return;
    setState(() => progress[game.id] = 0);

    for (var i = 1; i <= 25; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 70));
      if (!mounted) return;
      setState(() => progress[game.id] = i / 25);
    }

    setState(() {
      progress.remove(game.id);
      installed.add(game.id);
    });
    await saveInstalled();
    await playSound('audio/notification.mp3');

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${game.title} установлена'),
          action: SnackBarAction(
            label: 'Библиотека',
            onPressed: () => setState(() => tab = 2),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!signedIn) {
      return LoginPage(onLogin: signIn);
    }

    final pages = <Widget>[
      HomeScreen(
        installed: installed,
        onOpenStore: () => setState(() => tab = 1),
        onInstall: installGame,
      ),
      StoreScreen(
        installed: installed,
        progress: progress,
        onInstall: installGame,
      ),
      LibraryScreen(
        installed: installed,
        onOpenStore: () => setState(() => tab = 1),
      ),
      ProfileScreen(onLogout: signOut),
    ];

    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Главная',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag_rounded),
            label: 'PSR Store',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Библиотека',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final Future<void> Function(String login, String password) onLogin;

  const LoginPage({super.key, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final login = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool busy = false;

  @override
  void dispose() {
    login.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() => busy = true);
    await widget.onLogin(login.text, password.text);
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0477E7), Color(0xFF003B91)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const Icon(
                      Icons.sports_esports_rounded,
                      color: Colors.white,
                      size: 72,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'PSR3',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Войдите, чтобы продолжить',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 38),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 30,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: login,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Логин',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: password,
                            obscureText: obscure,
                            onSubmitted: (_) => submit(),
                            decoration: InputDecoration(
                              labelText: 'Пароль',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => obscure = !obscure),
                                icon: Icon(
                                  obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: busy ? null : submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: psBlue,
                              ),
                              child: busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Войти'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Тестовый вход: подойдут любые непустые данные',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final Set<String> installed;
  final VoidCallback onOpenStore;
  final Future<void> Function(GameItem game) onInstall;

  const HomeScreen({
    super.key,
    required this.installed,
    required this.onOpenStore,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    final featured = games.take(3).toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 34),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0571E5), Color(0xFF0050B7)],
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.sports_esports, color: Colors.white),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Добро пожаловать',
                        style: TextStyle(color: Colors.white70),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'PSR3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.notifications_none_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Популярное',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onOpenStore,
                    child: const Text('Все игры'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 230,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: featured.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final game = featured[index];
                    return SizedBox(
                      width: 175,
                      child: GameCard(
                        game: game,
                        installed: installed.contains(game.id),
                        progress: null,
                        compact: true,
                        onInstall: () => onInstall(game),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F1FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.download_done_rounded,
                        color: psBlue,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        installed.isEmpty
                            ? 'Установленных игр пока нет'
                            : 'В библиотеке: ${installed.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class StoreScreen extends StatelessWidget {
  final Set<String> installed;
  final Map<String, double> progress;
  final Future<void> Function(GameItem game) onInstall;

  const StoreScreen({
    super.key,
    required this.installed,
    required this.progress,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          pinned: true,
          backgroundColor: pageBg,
          surfaceTintColor: pageBg,
          title: Text(
            'PSR Store',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final game = games[index];
                return GameCard(
                  game: game,
                  installed: installed.contains(game.id),
                  progress: progress[game.id],
                  onInstall: () => onInstall(game),
                );
              },
              childCount: games.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
          ),
        ),
      ],
    );
  }
}

class LibraryScreen extends StatelessWidget {
  final Set<String> installed;
  final VoidCallback onOpenStore;

  const LibraryScreen({
    super.key,
    required this.installed,
    required this.onOpenStore,
  });

  @override
  Widget build(BuildContext context) {
    final items = games.where((g) => installed.contains(g.id)).toList();

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.grid_view_rounded,
                size: 78,
                color: Color(0xFF9AA5B4),
              ),
              const SizedBox(height: 20),
              const Text(
                'Библиотека пуста',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Установленные игры будут появляться здесь.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: onOpenStore,
                child: const Text('Открыть PSR Store'),
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          pinned: true,
          backgroundColor: pageBg,
          surfaceTintColor: pageBg,
          title: Text(
            'Библиотека',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => GameCard(
                game: items[index],
                installed: true,
                progress: null,
                onInstall: () {},
              ),
              childCount: items.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
              childAspectRatio: 0.72,
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final Future<void> Function() onLogout;

  const ProfileScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        const CircleAvatar(
          radius: 44,
          backgroundColor: Color(0xFFE0ECFF),
          child: Icon(Icons.person_rounded, color: psBlue, size: 48),
        ),
        const SizedBox(height: 14),
        const Center(
          child: Text(
            'PSR3 User',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 28),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Версия приложения'),
            trailing: const Text('0.1.0'),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Выйти'),
            onTap: onLogout,
          ),
        ),
      ],
    );
  }
}

class GameCard extends StatelessWidget {
  final GameItem game;
  final bool installed;
  final double? progress;
  final VoidCallback onInstall;
  final bool compact;

  const GameCard({
    super.key,
    required this.game,
    required this.installed,
    required this.progress,
    required this.onInstall,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final installing = progress != null;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ColoredBox(
              color: const Color(0xFFE8ECF2),
              child: SvgPicture.asset(
                game.cover,
                fit: BoxFit.cover,
                placeholderBuilder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 12 : 13,
              10,
              compact ? 12 : 13,
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 8),
                if (installing) ...[
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 5),
                  Text(
                    '${((progress ?? 0) * 100).round()}%',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ] else
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: installed
                        ? OutlinedButton.icon(
                            onPressed: onInstall,
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Установлено'),
                          )
                        : FilledButton(
                            onPressed: onInstall,
                            style: FilledButton.styleFrom(
                              backgroundColor: psBlue,
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text('Установить'),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
