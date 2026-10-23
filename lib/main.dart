import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

void main() => runApp(const PSR3App());

class C {
  static const bg = Color(0xFF0B0E14);
  static const card = Color(0xFF1F232B);
  static const card2 = Color(0xFF161A21);
  static const blue = Color(0xFF0070D1);
  static const muted = Color(0xFF8E939D);
}

enum Stage { connect, blackout, ready }

class Game {
  final int id, seconds;
  final String name, dev, subtitle, description;
  final bool beta;
  final IconData icon;
  const Game(this.id, this.name, this.dev, this.subtitle, this.description,
      this.seconds, this.beta, this.icon);
}

const gameList = <Game>[
  Game(1, 'MP3Dtest', 'ReGame LAB + Playstation Apsy',
      'Minecraft Parkour 3D test game',
      'Тестовая 3D-игра в стиле Minecraft. Проект создан на платформе ReGame LAB + Playstation Apsy для проверки паркура, управления и игровых возможностей PSR3.',
      24, true, Icons.view_in_ar_rounded),
  Game(2, 'Neon Track', 'ReGame LAB', 'Аркадные заезды в неоновом городе',
      'Аркадная гоночная игра с короткими трассами и быстрыми перезапусками.',
      28, false, Icons.sports_motorsports_rounded),
  Game(3, 'Cube Runner', 'Playstation Apsy', 'Раннер с препятствиями',
      'Быстрый раннер: проходи уровни, избегай препятствий и собирай игровые призы.',
      22, false, Icons.crop_square_rounded),
  Game(4, 'ReGame Arena', 'ReGame LAB', 'Мини-арена для быстрых матчей',
      'Небольшая тестовая арена для коротких игровых сессий и проверки управления.',
      34, true, Icons.sports_esports_rounded),
  Game(5, 'Sky Lines Beta', 'ReGame LAB', 'Полёт между платформами',
      'Экспериментальная игра с воздушными трассами и тестовыми испытаниями.',
      30, true, Icons.flight_takeoff_rounded),
  Game(6, 'Pixel Drift', 'Playstation Apsy', 'Пиксельная аркада на время',
      'Лёгкая аркада с короткими заездами на время для библиотеки PSR3.',
      26, false, Icons.speed_rounded),
];

class PSR3Controller extends ChangeNotifier {
  Stage stage = Stage.connect;
  bool mock = true;
  bool connecting = false;
  String esp = 'http://192.168.4.1';
  String? error;
  int avatar = 0;
  final installed = <int>{2, 3, 4, 5};
  final progress = <int, double>{};
  final timers = <int, Timer>{};

  bool isInstalled(int id) => installed.contains(id);
  bool isInstalling(int id) => progress.containsKey(id);

  Future<void> connect() async {
    if (connecting) return;
    connecting = true;
    error = null;
    notifyListeners();
    bool ok;
    if (mock) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      ok = true;
    } else {
      ok = await ping();
    }
    connecting = false;
    if (!ok) {
      error = 'Не удалось подключиться к ESP32: ' + esp;
      notifyListeners();
      return;
    }
    stage = Stage.blackout;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    stage = Stage.ready;
    notifyListeners();
  }

  Future<bool> ping() async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      final req = await client.getUrl(Uri.parse(esp + '/status'));
      final res = await req.close().timeout(const Duration(seconds: 3));
      await res.drain<void>();
      return res.statusCode >= 200 && res.statusCode < 500;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<bool> sendGameId(Game g) async {
    if (mock) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return true;
    }
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      final uri = Uri.parse(esp + '/game').replace(queryParameters: {
        'id': g.id.toString(),
        'name': g.name,
      });
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write('{"gameId":' + g.id.toString() + ',"gameName":"' + g.name + '"}');
      final res = await req.close().timeout(const Duration(seconds: 4));
      await res.drain<void>();
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  Future<bool> install(Game g) async {
    if (isInstalled(g.id) || isInstalling(g.id)) return true;
    if (!await sendGameId(g)) return false;
    progress[g.id] = 0;
    notifyListeners();
    var elapsed = 0;
    final total = g.seconds * 1000;
    timers[g.id] = Timer.periodic(const Duration(milliseconds: 250), (t) {
      elapsed += 250;
      final value = (elapsed / total).clamp(0.0, 1.0);
      progress[g.id] = value;
      if (value >= 1) {
        t.cancel();
        timers.remove(g.id);
        progress.remove(g.id);
        installed.add(g.id);
      }
      notifyListeners();
    });
    return true;
  }

  void cycleAvatar() {
    avatar = (avatar + 1) % 4;
    notifyListeners();
  }

  void setMock(bool v) {
    mock = v;
    notifyListeners();
  }

  void setEsp(String v) {
    var s = v.trim();
    if (s.isEmpty) return;
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'http://' + s;
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    esp = s;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final t in timers.values) {
      t.cancel();
    }
    super.dispose();
  }
}

class PSR3App extends StatefulWidget {
  const PSR3App({super.key});
  @override
  State<PSR3App> createState() => _PSR3AppState();
}

class _PSR3AppState extends State<PSR3App> {
  late final PSR3Controller controller;
  @override
  void initState() {
    super.initState();
    controller = PSR3Controller();
  }
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PSR3',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: C.bg,
        colorScheme: const ColorScheme.dark(primary: C.blue, surface: C.card),
        useMaterial3: true,
        fontFamily: 'Segoe UI',
      ),
      home: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          if (controller.stage == Stage.blackout) {
            return const ColoredBox(color: Colors.black);
          }
          if (controller.stage == Stage.ready) {
            return Shell(controller: controller);
          }
          return ConnectPage(controller: controller);
        },
      ),
    );
  }
}

class ConnectPage extends StatelessWidget {
  final PSR3Controller controller;
  const ConnectPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sports_esports_rounded, size: 80, color: C.blue),
                const SizedBox(height: 16),
                const Text('PSR3',
                    style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
                const Text('Playstation 3 Remale',
                    style: TextStyle(color: C.muted, fontSize: 16)),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: C.card, borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    children: [
                      const Icon(Icons.router_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(controller.mock
                            ? 'Mock Mode — ESP32 не требуется'
                            : controller.esp),
                      ),
                      Switch(
                        value: controller.mock,
                        onChanged: controller.connecting ? null : controller.setMock,
                      ),
                    ],
                  ),
                ),
                if (controller.error != null) ...[
                  const SizedBox(height: 10),
                  Text(controller.error!,
                      style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: controller.connecting ? null : controller.connect,
                    icon: controller.connecting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.link_rounded),
                    label: Text(controller.connecting
                        ? 'Подключение...'
                        : 'Подключиться к PSR3'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  final PSR3Controller controller;
  const Shell({super.key, required this.controller});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(c: widget.controller),
      StorePage(c: widget.controller),
      LibraryPage(c: widget.controller),
      ProfilePage(c: widget.controller),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        height: 72,
        backgroundColor: C.card,
        indicatorColor: C.blue.withOpacity(.22),
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag), label: 'PSR Store'),
          NavigationDestination(icon: Icon(Icons.video_library_outlined),
              selectedIcon: Icon(Icons.video_library), label: 'Библиотека'),
          NavigationDestination(icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person), label: 'Профиль'),
        ],
      ),
    );
  }
}

class Frame extends StatelessWidget {
  final Widget child;
  const Frame(this.child, {super.key});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1050), child: child),
  );
}

class HomePage extends StatelessWidget {
  final PSR3Controller c;
  const HomePage({super.key, required this.c});
  @override
  Widget build(BuildContext context) {
    return Frame(ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(children: [
          Avatar(c: c, size: 48),
          const SizedBox(width: 12),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Максим Волошин',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text('PSR3 Online',
                  style: TextStyle(color: C.muted, fontSize: 13)),
            ],
          )),
          Signal(mock: c.mock),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => showSettings(context, c),
            icon: const Icon(Icons.settings_outlined),
          ),
        ]),
        const SizedBox(height: 28),
        const Text('Новинки',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        HeroCard(game: gameList[0],
            onTap: () => openGame(context, c, gameList[0])),
        const SizedBox(height: 28),
        const Text('Обновления',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        SizedBox(
          height: 175,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => MiniCard(
              game: gameList[i + 1],
              onTap: () => openGame(context, c, gameList[i + 1]),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Text('Бета-игры',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ...gameList.where((g) => g.beta).map((g) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GameTile(game: g, c: c,
              onTap: () => openGame(context, c, g)),
        )),
      ],
    ));
  }
}

class StorePage extends StatelessWidget {
  final PSR3Controller c;
  const StorePage({super.key, required this.c});
  @override
  Widget build(BuildContext context) {
    return Frame(ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Row(children: [
          Text('PSR Store',
              style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900)),
          Spacer(),
          Icon(Icons.search_rounded, color: C.muted),
        ]),
        const SizedBox(height: 5),
        const Text('Все игры бесплатные',
            style: TextStyle(color: C.muted)),
        const SizedBox(height: 20),
        HeroCard(game: gameList[0],
            onTap: () => openGame(context, c, gameList[0])),
        const SizedBox(height: 26),
        const Row(children: [
          Text('Все игры',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Spacer(),
          Text('13+', style: TextStyle(color: C.muted)),
        ]),
        const SizedBox(height: 12),
        ...gameList.map((g) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GameTile(game: g, c: c,
              onTap: () => openGame(context, c, g)),
        )),
      ],
    ));
  }
}

class LibraryPage extends StatefulWidget {
  final PSR3Controller c;
  const LibraryPage({super.key, required this.c});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.c,
      builder: (_, __) {
        final list = tab == 0
            ? gameList
            : gameList.where((g) => widget.c.isInstalled(g.id)).toList();
        return Frame(ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Библиотека',
                style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900)),
            const SizedBox(height: 18),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Все')),
                ButtonSegment(value: 1, label: Text('Установленные')),
              ],
              selected: {tab},
              onSelectionChanged: (v) => setState(() => tab = v.first),
            ),
            const SizedBox(height: 18),
            ...list.map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GameTile(game: g, c: widget.c,
                  onTap: () => openGame(context, widget.c, g)),
            )),
          ],
        ));
      },
    );
  }
}

class ProfilePage extends StatelessWidget {
  final PSR3Controller c;
  const ProfilePage({super.key, required this.c});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        final installedGames =
            gameList.where((g) => c.isInstalled(g.id)).take(4).toList();
        return Frame(ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('SONY',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
                    letterSpacing: 3)),
            const SizedBox(height: 22),
            Row(children: [
              GestureDetector(
                onDoubleTap: () {
                  c.cycleAvatar();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Аватар изменён'),
                    duration: Duration(milliseconds: 800),
                  ));
                },
                child: Tooltip(
                    message: 'Двойное нажатие — сменить аватар',
                    child: Avatar(c: c, size: 92)),
              ),
              const SizedBox(width: 20),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Максим Волошин',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  Text('Игрок PSR3', style: TextStyle(color: C.muted)),
                ],
              )),
            ]),
            const SizedBox(height: 22),
            const Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Уровень 12',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: .68, minHeight: 8, backgroundColor: C.card,
                    valueColor: AlwaysStoppedAnimation<Color>(C.blue),
                  ),
                ],
              )),
              SizedBox(width: 18),
              Text('PSR3 (Playstation 3 Remale)',
                  style: TextStyle(color: C.muted, fontSize: 13)),
            ]),
            const SizedBox(height: 30),
            const Text('Игровые призы',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Row(children: [
              Expanded(child: Trophy(icon: Icons.emoji_events, value: '18',
                  label: 'Трофеев')),
              SizedBox(width: 10),
              Expanded(child: Trophy(icon: Icons.workspace_premium, value: '4',
                  label: 'Золотых')),
              SizedBox(width: 10),
              Expanded(child: Trophy(icon: Icons.stars, value: '68%',
                  label: 'Прогресс')),
            ]),
            const SizedBox(height: 30),
            Row(children: [
              const Text('Установленные игры',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(installedGames.length.toString() + '/4',
                  style: const TextStyle(color: C.muted)),
            ]),
            const SizedBox(height: 12),
            ...installedGames.map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GameTile(game: g, c: c,
                  onTap: () => openGame(context, c, g)),
            )),
          ],
        ));
      },
    );
  }
}

class GamePage extends StatelessWidget {
  final PSR3Controller c;
  final Game game;
  const GamePage({super.key, required this.c, required this.game});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        final installed = c.isInstalled(game.id);
        final installing = c.isInstalling(game.id);
        final p = c.progress[game.id] ?? 0;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: C.bg,
            surfaceTintColor: Colors.transparent,
            title: const Text('PSR Store',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          body: Frame(ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
            children: [
              Container(
                height: 320,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF405B78), Color(0xFF182B40), C.bg],
                  ),
                ),
                child: Center(child: Icon(game.icon, size: 170,
                    color: Colors.white.withOpacity(.82))),
              ),
              const SizedBox(height: 18),
              Text(game.name,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
              Text(game.dev,
                  style: const TextStyle(color: C.muted, fontSize: 15)),
              const SizedBox(height: 16),
              Row(children: [
                const Chip(label: Text('Информация')),
                if (game.beta) ...[
                  const SizedBox(width: 8),
                  const Chip(label: Text('Beta')),
                ],
              ]),
              const SizedBox(height: 18),
              const StoreInfoCard(),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: C.card, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Бесплатно',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 13),
                    if (installing) ...[
                      LinearProgressIndicator(value: p, minHeight: 8,
                          backgroundColor: C.card2),
                      const SizedBox(height: 8),
                      Text('Установка ' + (p * 100).round().toString() +
                          '% • ' + game.seconds.toString() + ' сек.',
                          style: const TextStyle(color: C.muted)),
                    ] else
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor: Colors.white.withOpacity(.14),
                            disabledForegroundColor: C.muted,
                          ),
                          onPressed: installed ? null : () async {
                            final ok = await c.install(game);
                            if (!context.mounted || ok) return;
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('ESP32 не принял Game ID ' +
                                  game.id.toString()),
                            ));
                          },
                          icon: Icon(installed
                              ? Icons.check_circle : Icons.download_rounded),
                          label: Text(installed ? 'Установлено' : 'Скачать',
                              style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text('Game ID: ' + game.id.toString() +
                        ' • команда отправляется на ESP32 при старте установки',
                        style: const TextStyle(color: C.muted, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              const Feature(icon: Icons.sports_esports_rounded,
                  text: 'Поддерживается контроллер'),
              const Feature(icon: Icons.download_done_rounded,
                  text: 'Установка через систему PSR3'),
              if (game.beta)
                const Feature(icon: Icons.science_outlined,
                    text: 'Бета-версия'),
              const SizedBox(height: 18),
              const Text('Возрастная категория',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Row(children: [
                Container(
                  width: 92, height: 92, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE83C2F),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white, width: 5),
                  ),
                  child: const Text('13+',
                      style: TextStyle(fontSize: 33, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(width: 16),
                const Expanded(child: Text(
                  'Игра предназначена для игроков от 13 лет.',
                  style: TextStyle(color: C.muted),
                )),
              ]),
              const SizedBox(height: 28),
              const Text('Описание игры',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: C.card, borderRadius: BorderRadius.circular(16)),
                child: Text(game.description,
                    style: const TextStyle(fontSize: 15, height: 1.55)),
              ),
            ],
          )),
        );
      },
    );
  }
}

class StoreInfoCard extends StatelessWidget {
  const StoreInfoCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(15)),
    child: const Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PSR3', style: TextStyle(fontWeight: FontWeight.w900)),
        Text('Версия для PSR3',
            style: TextStyle(color: C.muted, fontSize: 13)),
      ]),
      Spacer(),
      Icon(Icons.chevron_right_rounded),
    ]),
  );
}

class Feature extends StatelessWidget {
  final IconData icon;
  final String text;
  const Feature({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 17),
    child: Row(children: [
      SizedBox(width: 62, child: Icon(icon, size: 34)),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 17))),
    ]),
  );
}

class HeroCard extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;
  const HeroCard({super.key, required this.game, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      height: 250,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF344A64), Color(0xFF17293F), Color(0xFF08111C)],
        ),
      ),
      child: Stack(children: [
        Align(
          alignment: Alignment.centerRight,
          child: Icon(game.icon, size: 150, color: Colors.white.withOpacity(.13)),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (game.beta) const Badge(
                backgroundColor: C.blue, label: Text('BETA')),
              const SizedBox(height: 8),
              Text(game.name,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(game.subtitle, style: const TextStyle(color: Color(0xFFD1D5DB))),
            ],
          ),
        ),
      ]),
    ),
  );
}

class MiniCard extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;
  const MiniCard({super.key, required this.game, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(game.icon, size: 50, color: C.blue),
        const Spacer(),
        Text(game.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        Text(game.dev, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: C.muted, fontSize: 12)),
      ]),
    ),
  );
}

class GameTile extends StatelessWidget {
  final Game game;
  final PSR3Controller c;
  final VoidCallback onTap;
  const GameTile({super.key, required this.game, required this.c, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final installed = c.isInstalled(game.id);
    final installing = c.isInstalling(game.id);
    final p = c.progress[game.id] ?? 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(15)),
        child: Row(children: [
          Container(
            width: 76, height: 76,
            decoration: BoxDecoration(color: C.card2,
                borderRadius: BorderRadius.circular(13)),
            child: Icon(game.icon, size: 36, color: C.blue),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(child: Text(game.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                if (game.beta) ...[
                  const SizedBox(width: 8),
                  const Badge(backgroundColor: C.blue, label: Text('BETA')),
                ],
              ]),
              const SizedBox(height: 5),
              Text(game.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: C.muted, fontSize: 13)),
              const SizedBox(height: 7),
              Text(installing
                      ? 'Установка ' + (p * 100).round().toString() + '%'
                      : installed ? 'Установлено' : 'Бесплатно • 13+',
                  style: TextStyle(
                    color: installing || installed ? C.blue : C.muted,
                    fontSize: 12, fontWeight: FontWeight.w700,
                  )),
            ],
          )),
          const Icon(Icons.chevron_right_rounded, color: C.muted),
        ]),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  final PSR3Controller c;
  final double size;
  const Avatar({super.key, required this.c, required this.size});
  static const gradients = [
    [Color(0xFF0070D1), Color(0xFF00A4FF)],
    [Color(0xFF6A35FF), Color(0xFFBD4BFF)],
    [Color(0xFF0D8F67), Color(0xFF2FD5A0)],
    [Color(0xFFB34624), Color(0xFFFF8B4A)],
  ];
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: gradients[c.avatar]),
      border: Border.all(color: Colors.white.withOpacity(.15)),
    ),
    child: Icon(Icons.person, size: size * .55),
  );
}

class Trophy extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const Trophy({super.key, required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 8),
    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(15)),
    child: Column(children: [
      Icon(icon, color: C.blue),
      const SizedBox(height: 7),
      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      Text(label, textAlign: TextAlign.center,
          style: const TextStyle(color: C.muted, fontSize: 12)),
    ]),
  );
}

class Signal extends StatelessWidget {
  final bool mock;
  const Signal({super.key, required this.mock});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: mock ? 'ESP: Mock Mode' : 'ESP32 подключена',
    child: Row(children: [
      for (var i = 0; i < 4; i++)
        Container(
          width: 4, height: 8.0 + i * 4,
          margin: const EdgeInsets.only(left: 3),
          decoration: BoxDecoration(
            color: i < 3 ? C.blue : C.muted,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
    ]),
  );
}

void openGame(BuildContext context, PSR3Controller c, Game g) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => GamePage(c: c, game: g),
  ));
}

Future<void> showSettings(BuildContext context, PSR3Controller c) async {
  final ctl = TextEditingController(text: c.esp);
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: C.card,
      title: const Text('Настройки PSR3'),
      content: SizedBox(
        width: 430,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mock Mode'),
            subtitle: const Text('Тест интерфейса без ESP32',
                style: TextStyle(color: C.muted)),
            value: c.mock,
            onChanged: c.setMock,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: ctl,
            decoration: const InputDecoration(
              labelText: 'Адрес ESP32',
              hintText: 'http://192.168.4.1',
              filled: true,
              fillColor: C.card2,
              border: OutlineInputBorder(),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(onPressed: () {
          c.setEsp(ctl.text);
          Navigator.pop(context);
        }, child: const Text('Сохранить')),
      ],
    ),
  );
  ctl.dispose();
}
