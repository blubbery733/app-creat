import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PSR3App());
}

class C {
  static const bg = Color(0xFF0D0F12);
  static const card = Color(0xFF191C21);
  static const card2 = Color(0xFF12151A);
  static const accent = Color(0xFF0B5D47);
  static const blue = Color(0xFF2687FF);
  static const muted = Color(0xFFA5ABB4);
  static const border = Color(0xFF2A2F37);
}

const appVersionLabel = '0.4.0 Beta';
const fullReleaseDate = '28 ноября 2026';
const profileNick = '@Maksimka77nolka2';

enum Stage { connect, blackout, ready }

class Game {
  final int id;
  final int seconds;
  final String name;
  final String developer;
  final String subtitle;
  final String description;
  final bool beta;
  final IconData icon;
  final String? coverAsset;
  final int sizeMb;
  final String rating;
  final double? priceUah;
  final bool newRelease;

  const Game(
    this.id,
    this.name,
    this.developer,
    this.subtitle,
    this.description,
    this.seconds,
    this.beta,
    this.icon, {
    this.coverAsset,
    this.sizeMb = 64,
    this.rating = '',
    this.priceUah,
    this.newRelease = false,
  });

  bool get isPaid => priceUah != null;
}

const games = <Game>[
  Game(101, 'Fortnite Online', 'PupgMasterBP + ReGame LAB', '14+ • Beta',
      'Fortnite — это бесплатная и постоянно развивающаяся многопользовательская игра, которая объединяет в себе целую вселенную уникальных развлечений.',
      150, true, Icons.sports_esports_rounded,
      coverAsset: 'assets/covers/fortnite.svg', sizeMb: 248, rating: '14+'),
  Game(102, 'CREATURE', 'ReGame', '15+ • Психологический хоррор',
      'Creature — это леденящий душу психологический хоррор-квест, который проверит вашу выдержку и умение выживать в условиях абсолютной изоляции.\n\nАтмосферный психологический хоррор: визуальный стиль и звуковое сопровождение полностью погружают в виртуальный мир.\n\nТактический геймплей и выживание: управляйте ресурсами, скрывайтесь от преследования и принимайте решения за считанные секунды.\n\nИнтригующие головоломки: изучайте собранные страницы, ищите скрытые ключи и механизмы, чтобы продвигаться вглубь сюжета.',
      180, false, Icons.flashlight_on_rounded,
      coverAsset: 'assets/covers/creature.svg', sizeMb: 176, rating: '15+'),
  Game(103, 'Minecraft Beta 2D', 'ReGame Studio', '7+ • Beta 2D',
      'Minecraft для PlayStation 3 Remake — это симулятор выживания и песочница, где весь мир состоит из блоков, а единственным ограничением является ваша фантазия.',
      70, true, Icons.grid_view_rounded,
      coverAsset: 'assets/covers/minecraft_beta.svg', sizeMb: 88, rating: '7+'),
  Game(104, 'Terraria', 'ReStation Studio (ReGame LAS)', '12+ • Приключение',
      'Terraria для PlayStation 3 Remake — это уникальное приключение, которое объединяет классические черты экшен-игр со свободой творчества, доступной только в «песочницах». Весь мир игры находится на кончиках ваших пальцев, пока вы сражаетесь за выживание, исследуете недра в поисках богатств или строите собственные города.',
      195, false, Icons.terrain_rounded,
      coverAsset: 'assets/covers/terraria.svg', sizeMb: 132, rating: '12+'),
  Game(105, 'GTA beta Digital', 'ReGame Studio • 2025', '18+ • Beta Digital',
      'Это двумерная песочница (2D Top-Down Shooter / Driving) с видом сверху, вдохновлённая классическими частями Grand Theft Auto. Игрок попадает в небольшой открытый город, состоящий из пиксельных блоков или векторных рисунков.',
      0, true, Icons.directions_car_rounded,
      coverAsset: 'assets/covers/gta_beta.svg', sizeMb: 310, rating: '18+', priceUah: 36.50, newRelease: true),
  Game(106, 'MP3D Test', 'Android App', 'Minecraft Parkour 3D test game',
      'Тот самый тестовый паркур PSR3. Небольшая Android-игра для проверки управления, прыжков и игровых возможностей проекта.',
      50, true, Icons.crop_square_rounded,
      coverAsset: null, sizeMb: 41),
];

class PSR3Controller extends ChangeNotifier {
  Stage stage = Stage.connect;
  bool mock = true;
  bool connecting = false;
  String esp = 'http://192.168.4.1';
  String? error;
  String? avatarPath;
  int signalBars = 3;

  final installed = <int>{106};
  final progress = <int, double>{};
  final timers = <int, Timer>{};
  final AudioPlayer audio = AudioPlayer();
  final ImagePicker picker = ImagePicker();

  PSR3Controller() { unawaited(loadSavedState()); }

  bool isInstalled(int id) => installed.contains(id);
  bool isInstalling(int id) => progress.containsKey(id);

  Color get signalColor {
    if (signalBars <= 1) return const Color(0xFFE64C4C);
    if (signalBars == 2) return const Color(0xFFD59A2D);
    if (signalBars == 3) return C.accent;
    return C.blue;
  }

  int get installedFreeCount => games.where((g) => !g.isPaid && installed.contains(g.id)).length;
  int get freeGamesCount => games.where((g) => !g.isPaid).length;
  int get trophyCount => installedFreeCount;
  int get goldCount => installedFreeCount ~/ 3;
  double get collectionProgress => freeGamesCount == 0 ? 0 : installedFreeCount / freeGamesCount;
  int get installedSizeMb => games.where((g) => installed.contains(g.id)).fold(0, (sum, g) => sum + g.sizeMb);

  Future<void> loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGames = prefs.getStringList('installed_game_ids_v4');
    final savedAvatar = prefs.getString('avatar_path');
    if (savedGames != null) {
      installed
        ..clear()
        ..addAll(savedGames.map(int.tryParse).whereType<int>());
      if (installed.isEmpty) installed.add(106);
    }
    if (savedAvatar != null && File(savedAvatar).existsSync()) avatarPath = savedAvatar;
    notifyListeners();
  }

  Future<void> saveInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('installed_game_ids_v4', installed.map((id) => id.toString()).toList());
  }

  Future<void> connect() async {
    if (connecting) return;
    connecting = true;
    error = null;
    notifyListeners();
    await Future<void>.delayed(const Duration(seconds: 4));
    connecting = false;
    stage = Stage.ready;
    signalBars = 3;
    notifyListeners();
  }

  Future<bool> install(Game game) async {
    if (game.isPaid || isInstalled(game.id) || isInstalling(game.id)) return false;
    try {
      await audio.stop();
      await audio.play(AssetSource('audio/install.mp3'));
    } catch (_) {}
    progress[game.id] = 0;
    notifyListeners();
    var elapsed = 0;
    final total = game.seconds * 1000;
    timers[game.id] = Timer.periodic(const Duration(milliseconds: 250), (timer) async {
      elapsed += 250;
      final value = (elapsed / total).clamp(0.0, 1.0);
      progress[game.id] = value;
      if (value >= 1) {
        timer.cancel();
        timers.remove(game.id);
        progress.remove(game.id);
        installed.add(game.id);
        await saveInstalled();
      }
      notifyListeners();
    });
    return true;
  }

  Future<void> pickAvatar() async {
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1200, maxHeight: 1200);
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final target = dir.path + '/psr3_avatar.jpg';
    await File(picked.path).copy(target);
    avatarPath = target;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatar_path', target);
    notifyListeners();
  }

  @override
  void dispose() {
    for (final timer in timers.values) { timer.cancel(); }
    unawaited(audio.dispose());
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
        colorScheme: const ColorScheme.dark(
          primary: C.accent,
          secondary: C.accent,
          surface: C.card,
        ),
        useMaterial3: true,
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
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('PSR3', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text('PlayStation 3 Remake', style: TextStyle(color: C.muted)),
                  const SizedBox(height: 42),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(22)),
                    child: controller.connecting
                        ? const Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.phone_android_rounded, color: Colors.white, size: 52),
                                  SizedBox(width: 18),
                                  ConnectingDots(),
                                  SizedBox(width: 18),
                                  Icon(Icons.sports_esports_rounded, color: Colors.white, size: 52),
                                ],
                              ),
                              SizedBox(height: 22),
                              Text('Подключение к PSR3…', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                              SizedBox(height: 6),
                              Text('Около 4 секунд', style: TextStyle(color: C.muted)),
                            ],
                          )
                        : const Column(
                            children: [
                              Icon(Icons.phone_android_rounded, color: Colors.white, size: 62),
                              SizedBox(height: 14),
                              Text('Подключение через консоль', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                              SizedBox(height: 6),
                              Text('Телефон подключится к PSR3.', style: TextStyle(color: C.muted)),
                            ],
                          ),
                  ),
                  const SizedBox(height: 18),
                  if (!controller.connecting)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: C.blue, foregroundColor: Colors.white),
                        onPressed: controller.connect,
                        icon: const Icon(Icons.link_rounded, color: Colors.white),
                        label: const Text('Подключиться через консоль', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ConnectingDots extends StatefulWidget {
  const ConnectingDots({super.key});
  @override
  State<ConnectingDots> createState() => _ConnectingDotsState();
}

class _ConnectingDotsState extends State<ConnectingDots> with SingleTickerProviderStateMixin {
  late final AnimationController a;
  @override
  void initState() {
    super.initState();
    a = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
  }
  @override
  void dispose() { a.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: a,
      builder: (_, __) => Row(
        children: List.generate(5, (i) {
          final on = ((a.value * 5).floor() % 5) == i;
          return Container(
            width: 8, height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(shape: BoxShape.circle, color: on ? C.blue : C.muted.withOpacity(.28)),
          );
        }),
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

  void select(int value) {
    setState(() => index = value);
    unawaited(widget.controller.playSound('install.mp3'));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(controller: widget.controller),
      StorePage(controller: widget.controller),
      LibraryPage(controller: widget.controller),
      ProfilePage(controller: widget.controller),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: index,
          children: pages,
        ),
      ),
      bottomNavigationBar: SquareBottomBar(
        selected: index,
        onSelected: select,
      ),
    );
  }
}

class SquareBottomBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;

  const SquareBottomBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  static const items = [
    (Icons.home_rounded, 'Главная'),
    (Icons.shopping_bag_rounded, 'PSR Store'),
    (Icons.grid_view_rounded, 'Библиотека'),
    (Icons.person_rounded, 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: C.card2,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
        child: Row(
          children: List.generate(
            items.length,
            (i) {
              final active = selected == i;
              final item = items[i];

              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelected(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: active ? C.accent : C.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: active
                                  ? C.accent
                                  : Colors.white.withOpacity(.05),
                            ),
                          ),
                          child: Icon(
                            item.$1,
                            color: active ? Colors.black : C.muted,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.$2,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight:
                                active ? FontWeight.w800 : FontWeight.w500,
                            color: active ? Colors.white : C.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class Frame extends StatelessWidget {
  final Widget child;

  const Frame(this.child, {super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: child,
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final PSR3Controller controller;
  const HomePage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Frame(
      ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
        children: [
          Row(
            children: [
              AvatarView(controller: controller, size: 48),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Максим Волошин', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  Text('Online', style: TextStyle(color: C.muted, fontSize: 13)),
                ]),
              ),
              Signal(controller: controller),
              IconButton(onPressed: () => showSettings(context, controller), icon: const Icon(Icons.settings_rounded, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 26),
          const Text('Новинки', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          SizedBox(
            height: 195,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: games.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => MiniCard(game: games[i], onTap: () => openGame(context, controller, games[i])),
            ),
          ),
          const SizedBox(height: 28),
          const SectionTitle(icon: Icons.update_rounded, title: 'Обновления приложений'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16)),
            child: const Row(children: [
              Icon(Icons.description_rounded, color: Colors.white, size: 30),
              SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Ничего нового', style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Новых приложений и обновлений пока нет.', style: TextStyle(color: C.muted)),
              ])),
            ]),
          ),
          const SizedBox(height: 28),
          const SectionTitle(icon: Icons.emoji_events_rounded, title: 'Трофеи, золотые и прогресс'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Trophy(icon: Icons.emoji_events_rounded, value: controller.trophyCount.toString(), label: 'Трофеев')),
            const SizedBox(width: 10),
            Expanded(child: Trophy(icon: Icons.workspace_premium_rounded, value: controller.goldCount.toString(), label: 'Золотых')),
            const SizedBox(width: 10),
            Expanded(child: Trophy(icon: Icons.bar_chart_rounded, value: (controller.collectionProgress * 100).round().toString() + '%', label: 'Прогресс')),
          ]),
        ],
      ),
    );
  }
}

class StorePage extends StatelessWidget {
  final PSR3Controller controller;
  const StorePage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final gta = games.firstWhere((g) => g.id == 105);
    return Frame(
      ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
        children: [
          const Row(children: [
            DecoratedBox(
              decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.all(Radius.circular(13))),
              child: Padding(padding: EdgeInsets.all(11), child: Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 25)),
            ),
            SizedBox(width: 12),
            Text('PSR Store', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 22),
          InkWell(
            onTap: () => openGame(context, controller, gta),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.blue)),
              child: Row(children: [
                SizedBox(width: 105, height: 105, child: ClipRRect(borderRadius: BorderRadius.circular(15), child: GameArtwork(game: gta))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: C.blue, borderRadius: BorderRadius.circular(20)), child: const Text('Новинка', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                  const SizedBox(height: 8),
                  Text(gta.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  const Text('36,50 ₴', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ])),
              ]),
            ),
          ),
          const SizedBox(height: 26),
          const SectionTitle(icon: Icons.apps_rounded, title: 'Все игры'),
          const SizedBox(height: 12),
          ...games.map((game) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GameTile(game: game, controller: controller, onTap: () => openGame(context, controller, game)),
          )),
        ],
      ),
    );
  }
}



class LibraryPage extends StatelessWidget {
  final PSR3Controller controller;
  const LibraryPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final visible = games.where((g) => controller.isInstalled(g.id)).toList();
        return Frame(
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
            children: [
              const Row(children: [
                Icon(Icons.grid_view_rounded, color: Colors.white, size: 28),
                SizedBox(width: 10),
                Text('Библиотека', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 6),
              const Text('Только установленные игры', style: TextStyle(color: C.muted)),
              const SizedBox(height: 18),
              if (visible.isEmpty)
                Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(16)), child: const Text('Установленных игр пока нет.'))
              else
                ...visible.map((game) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GameTile(game: game, controller: controller, onTap: () => openGame(context, controller, game)),
                )),
            ],
          ),
        );
      },
    );
  }
}



class ProfilePage extends StatelessWidget {
  final PSR3Controller controller;

  const ProfilePage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final installedGames = games
            .where((g) => controller.isInstalled(g.id))
            .take(4)
            .toList();

        return Frame(
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
            children: [
              const Text(
                'SONY',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  GestureDetector(
                    onDoubleTap: () async {
                      await controller.pickAvatar();
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AvatarView(
                          controller: controller,
                          size: 92,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: C.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.photo_camera_rounded,
                              size: 17,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Максим Волошин',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Дважды нажми на аватар, чтобы выбрать свою фотографию',
                          style: TextStyle(
                            color: C.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Уровень 12',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 7),
                        LinearProgressIndicator(
                          value: .68,
                          minHeight: 8,
                          backgroundColor: C.card,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(C.accent),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 18),
                  Flexible(
                    child: Text(
                      'PSR3 (Playstation 3 Remale)',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: C.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              SectionTitle(
                icon: Icons.emoji_events_rounded,
                title: 'Игровые призы',
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                    child: Trophy(
                      icon: Icons.emoji_events_rounded,
                      value: '18',
                      label: 'Трофеев',
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Trophy(
                      icon: Icons.workspace_premium_rounded,
                      value: '4',
                      label: 'Золотых',
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Trophy(
                      icon: Icons.stars_rounded,
                      value: '68%',
                      label: 'Прогресс',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  const Icon(
                    Icons.download_done_rounded,
                    color: C.accent,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Установленные игры',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    installedGames.length.toString() + '/4',
                    style: const TextStyle(color: C.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...installedGames.map(
                (game) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GameTile(
                    game: game,
                    controller: controller,
                    onTap: () => openGame(context, controller, game),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class GamePage extends StatelessWidget {
  final PSR3Controller controller;
  final Game game;

  const GamePage({
    super.key,
    required this.controller,
    required this.game,
  });

  String formatDuration(int seconds) {
    if (seconds < 60) return seconds.toString() + ' сек.';
    if (seconds == 60) return '1 мин.';
    if (seconds % 60 == 0) {
      return (seconds ~/ 60).toString() + ' мин.';
    }
    return (seconds ~/ 60).toString() +
        ' мин. ' +
        (seconds % 60).toString() +
        ' сек.';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final installed = controller.isInstalled(game.id);
        final installing = controller.isInstalling(game.id);
        final p = controller.progress[game.id] ?? 0;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: C.bg,
            surfaceTintColor: Colors.transparent,
            title: const Row(
              children: [
                Icon(
                  Icons.shopping_bag_rounded,
                  color: C.accent,
                ),
                SizedBox(width: 8),
                Text(
                  'PSR Store',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          body: Frame(
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 34),
              children: [
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: game.id == 1
                          ? const [
                              Color(0xFF405B78),
                              Color(0xFF17293F),
                              C.bg,
                            ]
                          : const [
                              Color(0xFF11452A),
                              Color(0xFF0F291D),
                              C.bg,
                            ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      game.icon,
                      size: 160,
                      color: Colors.white.withOpacity(.84),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  game.name,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  game.developer,
                  style: const TextStyle(
                    color: C.muted,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const InfoChip(
                      icon: Icons.info_rounded,
                      text: 'Информация',
                    ),
                    const InfoChip(
                      icon: Icons.child_care_rounded,
                      text: '13+',
                    ),
                    if (game.beta)
                      const InfoChip(
                        icon: Icons.science_rounded,
                        text: 'Beta',
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const StoreInfoCard(),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: C.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.lock_open_rounded,
                            color: C.accent,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Бесплатно',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      if (installing) ...[
                        LinearProgressIndicator(
                          value: p,
                          minHeight: 8,
                          backgroundColor: C.card2,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(C.accent),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.downloading_rounded,
                              size: 18,
                              color: C.accent,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'Установка ' +
                                    (p * 100).round().toString() +
                                    '% • ' +
                                    formatDuration(game.seconds),
                                style: const TextStyle(color: C.muted),
                              ),
                            ),
                          ],
                        ),
                      ] else
                        SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: C.accent,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor:
                                  Colors.white.withOpacity(.14),
                              disabledForegroundColor: C.muted,
                            ),
                            onPressed: installed
                                ? null
                                : () async {
                                    final ok =
                                        await controller.install(game);

                                    if (!context.mounted || ok) return;

                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'ESP32 не принял Game ID ' +
                                              game.id.toString(),
                                        ),
                                      ),
                                    );
                                  },
                            icon: Icon(
                              installed
                                  ? Icons.check_circle_rounded
                                  : Icons.download_rounded,
                            ),
                            label: Text(
                              installed ? 'Установлено' : 'Скачать',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.memory_rounded,
                            color: C.muted,
                            size: 18,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Game ID: ' +
                                  game.id.toString() +
                                  ' • команда отправляется на ESP32 при старте',
                              style: const TextStyle(
                                color: C.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                const Feature(
                  icon: Icons.sports_esports_rounded,
                  text: 'Поддерживается контроллер',
                ),
                const Feature(
                  icon: Icons.memory_rounded,
                  text: 'Установка управляется через ESP32',
                ),
                Feature(
                  icon: Icons.timer_rounded,
                  text: 'Время установки: ' + formatDuration(game.seconds),
                ),
                if (game.beta)
                  const Feature(
                    icon: Icons.science_rounded,
                    text: 'Бета-версия',
                  ),
                const SizedBox(height: 18),
                SectionTitle(
                  icon: Icons.child_care_rounded,
                  title: 'Возрастная категория',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE83C2F),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white,
                          width: 5,
                        ),
                      ),
                      child: const Text(
                        '13+',
                        style: TextStyle(
                          fontSize: 33,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Игра предназначена для игроков от 13 лет.',
                        style: TextStyle(color: C.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                SectionTitle(
                  icon: Icons.description_rounded,
                  title: 'Описание игры',
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: C.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    game.description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;

  const SectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: C.accent,
          size: 23,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          Text(
            trailing!,
            style: const TextStyle(color: C.muted),
          ),
        ],
      ],
    );
  }
}

class InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const InfoChip({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        icon,
        size: 17,
        color: C.accent,
      ),
      label: Text(text),
      backgroundColor: C.card,
      side: BorderSide.none,
    );
  }
}

class StoreInfoCard extends StatelessWidget {
  const StoreInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.videogame_asset_rounded,
            color: C.accent,
            size: 30,
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PSR3',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                'Версия для PSR3',
                style: TextStyle(
                  color: C.muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Spacer(),
          Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class Feature extends StatelessWidget {
  final IconData icon;
  final String text;

  const Feature({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: C.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: C.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class HeroCard extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;

  const HeroCard({
    super.key,
    required this.game,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 235,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF344A64),
              Color(0xFF17293F),
              Color(0xFF08111C),
            ],
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Icon(
                game.icon,
                size: 145,
                color: Colors.white.withOpacity(.13),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.new_releases_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'НОВИНКА',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    game.name,
                    style: const TextStyle(
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.subtitle,
                    style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MiniCard extends StatelessWidget {
  final Game game;
  final VoidCallback onTap;

  const MiniCard({
    super.key,
    required this.game,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 205,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: C.card2,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                game.icon,
                color: C.accent,
              ),
            ),
            const Spacer(),
            Text(
              game.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              game.developer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: C.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GameTile extends StatelessWidget {
  final Game game;
  final PSR3Controller controller;
  final VoidCallback onTap;

  const GameTile({
    super.key,
    required this.game,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final installed = controller.isInstalled(game.id);
    final installing = controller.isInstalling(game.id);
    final p = controller.progress[game.id] ?? 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: C.card2,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                game.icon,
                size: 35,
                color: C.accent,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          game.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (game.beta) ...[
                        const SizedBox(width: 7),
                        const Icon(
                          Icons.science_rounded,
                          size: 16,
                          color: C.accent,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    game.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: C.muted,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        installing
                            ? Icons.downloading_rounded
                            : installed
                                ? Icons.check_circle_rounded
                                : Icons.lock_open_rounded,
                        size: 16,
                        color: installing || installed
                            ? C.accent
                            : C.muted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        installing
                            ? 'Установка ' +
                                (p * 100).round().toString() +
                                '%'
                            : installed
                                ? 'Установлено'
                                : 'Бесплатно • 13+',
                        style: TextStyle(
                          color: installing || installed
                              ? C.accent
                              : C.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: C.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class AvatarView extends StatelessWidget {
  final PSR3Controller controller;
  final double size;

  const AvatarView({
    super.key,
    required this.controller,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final path = controller.avatarPath;

    if (path != null && File(path).existsSync()) {
      return ClipOval(
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            C.accent,
            Color(0xFF0E8F4A),
          ],
        ),
      ),
      child: Icon(
        Icons.person_rounded,
        size: size * .56,
        color: Colors.black,
      ),
    );
  }
}

class Trophy extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const Trophy({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 17,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: C.accent,
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: C.muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class Signal extends StatelessWidget {
  final bool mock;

  const Signal({
    super.key,
    required this.mock,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: mock ? 'ESP: Mock Mode' : 'ESP32 подключена',
      child: Row(
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 4,
              height: 8.0 + i * 4,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                color: i < 3 ? C.accent : C.muted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

void openGame(
  BuildContext context,
  PSR3Controller controller,
  Game game,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => GamePage(
        controller: controller,
        game: game,
      ),
    ),
  );
}

Future<void> showSettings(
  BuildContext context,
  PSR3Controller controller,
) async {
  final field = TextEditingController(text: controller.esp);

  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: C.card,
        title: const Row(
          children: [
            Icon(
              Icons.settings_rounded,
              color: C.accent,
            ),
            SizedBox(width: 8),
            Text('Настройки PSR3'),
          ],
        ),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mock Mode'),
                subtitle: const Text(
                  'Тест приложения без ESP32',
                  style: TextStyle(color: C.muted),
                ),
                value: controller.mock,
                onChanged: controller.setMock,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: field,
                decoration: const InputDecoration(
                  labelText: 'Адрес ESP32',
                  hintText: 'http://192.168.4.1',
                  filled: true,
                  fillColor: C.card2,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: C.accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              controller.setEsp(field.text);
              Navigator.pop(context);
            },
            child: const Text(
              'Сохранить',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      );
    },
  );

  field.dispose();
}
