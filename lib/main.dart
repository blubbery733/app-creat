import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() => runApp(const Psr3App());

const bg = Color(0xFF111214);
const surface = Color(0xFF18191C);
const surface2 = Color(0xFF202226);
const border = Color(0xFF32353B);
const green = Color(0xFF0B5BA7);
const greenSoft = Color(0xFF4AA9F8);
const muted = Color(0xFFA7A9AE);

class Psr3App extends StatelessWidget {
  const Psr3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PSR3',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: greenSoft,
          secondary: green,
          surface: surface,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface2,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: greenSoft),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

enum ConnectMode { esp32, remotePlay }
enum MainPage { system, settings }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool showSplash = true;
  bool chooseMode = true;
  bool streamMode = false;
  bool connected = false;
  bool demoMode = false;

  ConnectMode? mode;
  MainPage page = MainPage.system;

  String ip = '192.168.4.1';
  String ping = '—';
  String firmware = '—';
  String freeHeap = '—';
  String largestBlock = '—';
  String wifiRssi = '—';

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => showSplash = false);
    });
  }

  String get baseUrl => 'http://' + ip;

  @override
  Widget build(BuildContext context) {
    if (showSplash) return splash();
    if (streamMode) return stream();
    if (chooseMode) return chooser();
    return shell();
  }

  Widget splash() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Image.asset(
          'assets/psremake-logo.png',
          width: 310,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  Widget chooser() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1020),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Подключите консоль',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Выберите способ подключения к PSR3.',
                    style: TextStyle(color: muted, fontSize: 16),
                  ),
                  const SizedBox(height: 28),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final esp = ModeCard(
                        icon: Icons.memory_rounded,
                        title: 'ESP32',
                        subtitle: 'Состояние консоли, прошивка, ping и системная информация.',
                        onTap: () => begin(ConnectMode.esp32),
                      );
                      final remote = ModeCard(
                        icon: Icons.sports_esports_rounded,
                        title: 'Remote Play',
                        subtitle: 'Подключение по коду с телевизора и будущая трансляция PSR3.',
                        onTap: () => begin(ConnectMode.remotePlay),
                      );

                      if (constraints.maxWidth < 720) {
                        return Column(
                          children: [
                            esp,
                            const SizedBox(height: 16),
                            remote,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: esp),
                          const SizedBox(width: 16),
                          Expanded(child: remote),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> begin(ConnectMode selected) async {
    mode = selected;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,
        title: const Text('Подключитесь к сети PSR3'),
        content: const SizedBox(
          width: 430,
          child: Text(
            'Подключите компьютер к Wi-Fi сети PSR3. После подключения вернитесь в приложение.',
            style: TextStyle(color: muted, height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Назад'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Я подключился'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    if (selected == ConnectMode.remotePlay) {
      await remoteFlow();
    } else {
      await espFlow();
    }
  }

  Future<void> remoteFlow() async {
    final found = await loadingDialog(
      const Duration(seconds: 5),
      'Поиск PSR3',
      'Это может занять несколько минут.',
    );
    if (!found || !mounted) return;

    final code = await askCode();
    if (code == null || !mounted) return;

    final paired = demoMode ? true : await pairRemote(code);
    if (!mounted) return;

    if (!paired) {
      note('Код не подтверждён. Проверьте код на телевизоре и соединение с PSR3.');
      return;
    }

    final started = await loadingDialog(
      const Duration(milliseconds: 1800),
      'Подключение',
      'Запускаем Remote Play',
    );
    if (!started || !mounted) return;

    setState(() {
      streamMode = true;
      chooseMode = false;
      connected = true;
    });
  }

  Future<void> espFlow() async {
    final found = await loadingDialog(
      const Duration(milliseconds: 1300),
      'Поиск PSR3',
      'Это может занять несколько минут.',
    );
    if (!found || !mounted) return;

    final result = demoMode
        ? const ApiResult(true, 'Demo', <String, dynamic>{})
        : await getJson('/api/status');

    if (!mounted) return;
    if (!result.ok) {
      note(result.message);
      return;
    }

    setState(() {
      chooseMode = false;
      connected = true;
    });

    await refreshInfo();
  }

  Future<bool> loadingDialog(
    Duration duration,
    String title,
    String subtitle,
  ) async {
    if (!mounted) return false;

    var dialogOpen = true;
    final dialogFuture = showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => LoadingDialog(
        title: title,
        subtitle: subtitle,
        onCancel: () => Navigator.pop(dialogContext, false),
      ),
    ).whenComplete(() => dialogOpen = false);

    final result = await Future.any<bool>([
      dialogFuture.then((value) => value ?? false),
      Future<bool>.delayed(duration, () => true),
    ]);

    if (result && dialogOpen && mounted) {
      Navigator.of(context, rootNavigator: true).pop(true);
    }

    return result;
  }

  Future<String?> askCode() async {
    final controller = TextEditingController();
    String? error;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: surface,
          title: const Text('Введите код с телевизора'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: '4-значный код',
                counterText: '',
                errorText: error,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                  setDialogState(() => error = 'Введите ровно 4 цифры');
                  return;
                }
                Navigator.pop(dialogContext, value);
              },
              child: const Text('Подключиться'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    return result;
  }

  Widget stream() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Colors.black)),
          Positioned(
            top: 18,
            right: 18,
            child: IconButton(
              tooltip: 'Выйти из Remote Play',
              onPressed: () => setState(() {
                streamMode = false;
                chooseMode = true;
                connected = false;
              }),
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFF4A504C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget shell() {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 230,
              margin: const EdgeInsets.all(18),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PSR3',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text('ESP32', style: TextStyle(color: greenSoft)),
                  const SizedBox(height: 24),
                  NavItem(
                    icon: Icons.memory_rounded,
                    label: 'Система',
                    selected: page == MainPage.system,
                    onTap: () => setState(() => page = MainPage.system),
                  ),
                  const SizedBox(height: 8),
                  NavItem(
                    icon: Icons.settings_rounded,
                    label: 'Настройки',
                    selected: page == MainPage.settings,
                    onTap: () => setState(() => page = MainPage.settings),
                  ),
                  const Spacer(),
                  Text(
                    connected ? 'Подключено' : 'Нет связи',
                    style: TextStyle(
                      color: connected ? greenSoft : muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(ip, style: const TextStyle(color: muted)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: backToStart,
                      child: const Text('Отключиться'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 18, 18, 18),
                child: page == MainPage.system
                    ? systemPage()
                    : settingsPage(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget systemPage() {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          Panel(
            title: 'Подключение',
            width: 410,
            child: Column(
              children: [
                InfoRow(label: 'Статус', value: connected ? 'Подключено' : 'Нет связи'),
                InfoRow(label: 'IP', value: ip),
                InfoRow(label: 'Ping', value: ping),
                InfoRow(label: 'Прошивка', value: firmware),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: refreshInfo,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Обновить'),
                  ),
                ),
              ],
            ),
          ),
          Panel(
            title: 'Система',
            width: 410,
            child: Column(
              children: [
                InfoRow(label: 'Свободная память', value: freeHeap),
                InfoRow(label: 'Крупнейший блок', value: largestBlock),
                InfoRow(label: 'Wi-Fi RSSI', value: wifiRssi),
              ],
            ),
          ),
          Panel(
            title: 'Действия',
            width: 410,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('Перезагрузка'),
                  onPressed: () => postCommand('/api/restart'),
                ),
                ActionChip(
                  avatar: const Icon(Icons.system_update_alt_rounded, size: 18),
                  label: const Text('Update Mode'),
                  onPressed: () => postCommand('/api/update-mode'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget settingsPage() {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          Panel(
            title: 'Соединение',
            width: 500,
            child: Column(
              children: [
                TextFormField(
                  initialValue: ip,
                  decoration: const InputDecoration(
                    labelText: 'IP ESP32',
                    helperText: 'Указывайте только IP. /api/... приложение добавит само.',
                  ),
                  onFieldSubmitted: saveIp,
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'По умолчанию: 192.168.4.1',
                    style: TextStyle(color: muted),
                  ),
                ),
              ],
            ),
          ),
          Panel(
            title: 'Тестирование',
            width: 360,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: demoMode,
              title: const Text('Демо-режим'),
              subtitle: const Text(
                'Проверка интерфейса без реальной консоли.',
                style: TextStyle(color: muted),
              ),
              onChanged: (value) => setState(() => demoMode = value),
            ),
          ),
          const Panel(
            title: 'Remote Play',
            width: 360,
            child: Text(
              'Экран трансляции пока полностью чёрный. Он зарезервирован под будущий рендер или поток после переноса проекта SB3.',
              style: TextStyle(color: muted, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  void saveIp(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return;
    setState(() => ip = clean);
    note('IP сохранён');
  }

  Future<void> refreshInfo() async {
    if (demoMode) {
      setState(() {
        connected = true;
        ping = '4 ms';
        firmware = 'Demo';
        freeHeap = 'Demo';
        largestBlock = 'Demo';
        wifiRssi = '-48 dBm';
      });
      return;
    }

    final watch = Stopwatch()..start();
    final result = await getJson('/api/status');
    watch.stop();

    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        connected = false;
        ping = '—';
      });
      note(result.message);
      return;
    }

    final data = result.data;
    setState(() {
      connected = true;
      ping = watch.elapsedMilliseconds.toString() + ' ms';
      firmware = field(data, 'firmware');
      freeHeap = field(data, 'free_heap');
      largestBlock = field(data, 'largest_block');
      wifiRssi = field(data, 'wifi_rssi');
    });
  }

  String field(Map<String, dynamic> data, String name) {
    final value = data[name];
    return value == null ? '—' : value.toString();
  }

  Future<bool> pairRemote(String code) async {
    final result = await postJson(
      '/api/remote/pair',
      <String, dynamic>{'code': code},
    );
    return result.ok;
  }

  Future<void> postCommand(String path) async {
    final result = demoMode
        ? const ApiResult(true, 'Demo', <String, dynamic>{})
        : await postJson(path, const <String, dynamic>{});
    if (!mounted) return;
    note(result.ok ? 'Команда отправлена' : result.message);
  }

  Future<ApiResult> getJson(String path) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);

    try {
      final uri = Uri.parse(baseUrl + path);
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 5));
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ApiResult(
          false,
          'PSR3 ответил HTTP ' + response.statusCode.toString(),
          const <String, dynamic>{},
        );
      }

      if (body.trim().isEmpty) {
        return const ApiResult(true, 'OK', <String, dynamic>{});
      }

      final decoded = jsonDecode(body);
      return ApiResult(
        true,
        'OK',
        decoded is Map<String, dynamic>
            ? decoded
            : const <String, dynamic>{},
      );
    } on TimeoutException {
      return const ApiResult(
        false,
        'Время ожидания ESP32 истекло',
        <String, dynamic>{},
      );
    } on SocketException catch (e) {
      return ApiResult(
        false,
        'Нет связи с ESP32: ' + e.message,
        const <String, dynamic>{},
      );
    } catch (e) {
      return ApiResult(
        false,
        'Ошибка подключения: ' + e.toString(),
        const <String, dynamic>{},
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<ApiResult> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);

    try {
      final uri = Uri.parse(baseUrl + path);
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close().timeout(const Duration(seconds: 5));
      final text = await utf8.decoder.bind(response).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ApiResult(
          false,
          'PSR3 ответил HTTP ' + response.statusCode.toString(),
          const <String, dynamic>{},
        );
      }

      if (text.trim().isEmpty) {
        return const ApiResult(true, 'OK', <String, dynamic>{});
      }

      final decoded = jsonDecode(text);
      return ApiResult(
        true,
        'OK',
        decoded is Map<String, dynamic>
            ? decoded
            : const <String, dynamic>{},
      );
    } on TimeoutException {
      return const ApiResult(
        false,
        'Время ожидания ESP32 истекло',
        <String, dynamic>{},
      );
    } on SocketException catch (e) {
      return ApiResult(
        false,
        'Нет связи с ESP32: ' + e.message,
        const <String, dynamic>{},
      );
    } catch (e) {
      return ApiResult(
        false,
        'Ошибка подключения: ' + e.toString(),
        const <String, dynamic>{},
      );
    } finally {
      client.close(force: true);
    }
  }

  void backToStart() {
    setState(() {
      chooseMode = true;
      streamMode = false;
      connected = false;
      mode = null;
      page = MainPage.system;
    });
  }

  void note(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class ApiResult {
  final bool ok;
  final String message;
  final Map<String, dynamic> data;

  const ApiResult(this.ok, this.message, this.data);
}

class LoadingDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final VoidCallback onCancel;

  const LoadingDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onCancel,
  });

  @override
  State<LoadingDialog> createState() => _LoadingDialogState();
}

class _LoadingDialogState extends State<LoadingDialog> {
  int activeDot = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (mounted) setState(() => activeDot = (activeDot + 1) % 3);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSearch = widget.title == 'Поиск PSR3';

    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: const Color(0xFF111214),
        shape: const RoundedRectangleBorder(),
        child: SizedBox.expand(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 34,
                    vertical: 26,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF08090A),
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 24,
                              spreadRadius: 8,
                              color: Color(0x331A1A1A),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 31,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isSearch
                            ? 'Это может занять несколько минут.'
                            : widget.subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFAAAAAF),
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.desktop_windows_rounded,
                            color: Colors.white,
                            size: 45,
                          ),
                          const SizedBox(width: 26),
                          const Icon(
                            Icons.phone_android_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                          const SizedBox(width: 36),
                          for (var i = 0; i < 3; i++) ...[
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: i == activeDot ? 1 : 0.45,
                              child: Container(
                                width: 15,
                                height: 15,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            if (i != 2) const SizedBox(width: 22),
                          ],
                          const SizedBox(width: 36),
                          const Icon(
                            Icons.sports_esports_rounded,
                            color: Colors.white,
                            size: 56,
                          ),
                        ],
                      ),
                      const SizedBox(height: 44),
                      Container(
                        width: 500,
                        height: 82,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(50),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0x002F3034),
                              Color(0x663A3C40),
                              Color(0x88585A5F),
                              Color(0x663A3C40),
                              Color(0x002F3034),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x553E4045),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(flex: 2),
                      TextButton(
                        onPressed: widget.onCancel,
                        child: const Text(
                          'ОТМЕНИТЬ',
                          style: TextStyle(
                            color: Color(0xFF3FA9F5),
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ModeCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const ModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<ModeCard> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(26),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 230,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: hover ? surface2 : surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: hover ? green : border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0x330B5BA7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(widget.icon, color: greenSoft, size: 30),
              ),
              const Spacer(),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                style: const TextStyle(color: muted, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0x330B5BA7) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? greenSoft : muted),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  final String title;
  final double width;
  final Widget child;

  const Panel({
    super.key,
    required this.title,
    required this.width,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: muted)),
          ),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
