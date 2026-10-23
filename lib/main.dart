import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'startup_sound.dart';

void main() => runApp(const Psr3App());

const bg = Color(0xFF070A08);
const surface = Color(0xFF101612);
const surface2 = Color(0xFF151E18);
const border = Color(0xFF28372D);
const green = Color(0xFF246B45);
const greenSoft = Color(0xFF78D39D);
const muted = Color(0xFFA8B6AC);

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
        fontFamily: 'ZenMaru',
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

  ConnectMode? mode;
  MainPage page = MainPage.system;

  String ip = '192.168.4.1';
  double? pingMs;
  String firmware = '—';
  String freeHeap = '—';
  String largestBlock = '—';
  String consoleMode = 'unknown';
  String consoleError = '—';
  Timer? statusTimer;
  final AudioPlayer remotePlayer = AudioPlayer();
  bool remoteSoundPlayed = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => showSplash = false);
    });
  }

  @override
  void dispose() {
    statusTimer?.cancel();
    unawaited(remotePlayer.dispose());
    super.dispose();
  }

  String get baseUrl => 'http://' + ip;

  bool get safeMode {
    final value = consoleMode.toLowerCase().replaceAll('-', '_');
    return value == 'safe' || value == 'safe_mode';
  }

  String get modeLabel {
    switch (consoleMode.toLowerCase().replaceAll('-', '_')) {
      case 'on':
        return 'On';
      case 'standby':
        return 'Standby';
      case 'safe':
      case 'safe_mode':
        return 'Safe Mode';
      case 'update':
      case 'update_mode':
        return 'Update Mode';
      default:
        return '—';
    }
  }

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
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1100),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.88 + (0.12 * value),
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 122,
                height: 122,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF78D39D),
                    width: 2.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x6628A966),
                      blurRadius: 34,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: Color(0x3378D39D),
                      blurRadius: 72,
                      spreadRadius: 14,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Color(0x4428A966),
                            Color(0x16070A08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const Text(
                      '3',
                      style: TextStyle(
                        fontSize: 68,
                        height: 1,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        letterSpacing: -4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'PSR3',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 10,
                ),
              ),
              const SizedBox(height: 9),
              Container(
                width: 148,
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    colors: [
                      Colors.transparent,
                      Color(0xFF78D39D),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xAA28A966),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                        icon: Icons.wifi_rounded,
                        title: 'Прямое подключение',
                        onTap: () => begin(ConnectMode.esp32),
                      );
                      final remote = ModeCard(
                        icon: Icons.sports_esports_rounded,
                        title: 'Remote Play',
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
    final status = await getJson('/api/status');

    if (!mounted) return;

    if (status.ok) {
      final statusMode = field(status.data, 'mode').toLowerCase();
      if (statusMode == 'safe' || statusMode == 'safe_mode') {
        note('Remote Play недоступен в Safe Mode. Используйте «Прямое подключение».');
        return;
      }
    }

    final found = await remoteLoadingDialog(const Duration(seconds: 4));
    if (!found || !mounted) return;

    final code = await askCode();
    if (code == null || !mounted) return;

    final paired = await pairRemote(code);
    if (!mounted) return;
    if (!paired) return;

    final started = await remoteLoadingDialog(
      const Duration(milliseconds: 950),
    );
    if (!started || !mounted) return;

    setState(() {
      streamMode = true;
      chooseMode = false;
      connected = true;
      remoteSoundPlayed = false;
    });

    unawaited(playRemoteStartupSound());
  }

  Future<void> espFlow() async {
    final found = await directLoadingDialog(
      const Duration(milliseconds: 1500),
    );
    if (!found || !mounted) return;

    final result = await getJson('/api/status');

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
    startStatusPolling();
  }

  Future<bool> remoteLoadingDialog(Duration duration) async {
    if (!mounted) return false;
    return timedDialog(
      duration,
      (dialogContext) => RemoteLoadingDialog(
        onCancel: () => Navigator.pop(dialogContext, false),
      ),
    );
  }

  Future<bool> directLoadingDialog(Duration duration) async {
    if (!mounted) return false;
    return timedDialog(
      duration,
      (dialogContext) => DirectLoadingDialog(
        onCancel: () => Navigator.pop(dialogContext, false),
      ),
    );
  }

  Future<bool> timedDialog(
    Duration duration,
    Widget Function(BuildContext) builder,
  ) async {
    var dialogOpen = true;
    final dialogFuture = showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: builder,
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
              textInputAction: TextInputAction.done,
              onSubmitted: (value) {
                final clean = value.trim();
                if (!RegExp(r'^\d{4}
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

  void exitRemotePlay() {
    unawaited(remotePlayer.stop());
    setState(() {
      streamMode = false;
      chooseMode = true;
      connected = false;
      remoteSoundPlayed = false;
    });
  }

  Widget stream() {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): exitRemotePlay,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF050806),
          body: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: RemoteWavesPainter()),
              ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, 0.15),
                      radius: 1.05,
                      colors: [
                        Color(0x2228A966),
                        Color(0x110F5D3B),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sports_esports_rounded,
                      size: 74,
                      color: greenSoft,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Remote Play',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Подключение установлено',
                      style: TextStyle(color: muted, fontSize: 15),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'ESC — выйти',
                      style: TextStyle(color: Color(0xFF657269), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
                  const Text('Прямое подключение', style: TextStyle(color: greenSoft)),
                  const SizedBox(height: 24),
                  NavItem(
                    icon: Icons.memory_rounded,
                    label: 'Система',
                    selected: page == MainPage.system,
                    onTap: () => setState(() => page = MainPage.system),
                  ),
                  if (!safeMode) ...[
                    const SizedBox(height: 8),
                    NavItem(
                      icon: Icons.settings_rounded,
                      label: 'Настройки',
                      selected: page == MainPage.settings,
                      onTap: () => setState(() => page = MainPage.settings),
                    ),
                  ],
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
                child: safeMode || page == MainPage.system
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
    final connectionPanel = Panel(
      title: 'Подключение',
      width: 410,
      child: Column(
        children: [
          InfoRow(label: 'Статус', value: connected ? 'Подключено' : 'Нет связи'),
          InfoRow(label: 'Режим', value: modeLabel),
          InfoRow(label: 'IP', value: ip),
          PingInfoRow(pingMs: pingMs),
          InfoRow(label: 'Прошивка', value: firmware),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => refreshInfo(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Обновить'),
            ),
          ),
        ],
      ),
    );

    final systemPanel = Panel(
      title: 'Система',
      width: 410,
      child: safeMode
          ? Column(
              children: [
                InfoRow(label: 'Свободная память', value: freeHeap),
                InfoRow(label: 'Ошибка', value: consoleError),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => postCommand('/api/restart'),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Перезагрузка'),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                InfoRow(label: 'Свободная память', value: freeHeap),
                InfoRow(label: 'Крупнейший блок', value: largestBlock),
              ],
            ),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [connectionPanel, systemPanel],
          ),
          if (safeMode) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: 836,
              child: FilledButton.icon(
                onPressed: beginUpdate,
                icon: const Icon(Icons.system_update_alt_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Update'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget settingsPage() {
    if (safeMode) return systemPage();

    return SingleChildScrollView(
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          Panel(
            title: 'Управление консолью',
            width: 430,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => postCommand('/api/restart'),
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Перезагрузка'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: beginUpdate,
                  icon: const Icon(Icons.system_update_alt_rounded),
                  label: const Text('Update'),
                ),
              ],
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

  void startStatusPolling() {
    statusTimer?.cancel();
    statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && connected && mode == ConnectMode.esp32) {
        refreshInfo(silent: true);
      }
    });
  }

  Future<void> refreshInfo({bool silent = false}) async {
    final watch = Stopwatch()..start();
    final result = await getJson('/api/status');
    watch.stop();

    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        connected = false;
        pingMs = null;
      });
      if (!silent) note(result.message);
      return;
    }

    final data = result.data;
    setState(() {
      connected = true;
      pingMs = watch.elapsedMilliseconds.toDouble();
      firmware = field(data, 'firmware');
      freeHeap = formatMb(data['free_heap']);
      largestBlock = formatMb(data['largest_block']);
      final rawMode = field(data, 'mode');
      consoleMode = rawMode == '—' ? field(data, 'state') : rawMode;
      consoleError = field(data, 'error');
      if (safeMode) page = MainPage.system;
    });
  }

  String formatMb(dynamic value) {
    if (value == null) return '—';
    final raw = value is num
        ? value.toDouble()
        : double.tryParse(value.toString().replaceAll(RegExp(r'[^0-9.-]'), ''));
    if (raw == null) return '—';
    return '${(raw / (1024 * 1024)).toStringAsFixed(2)} МБ';
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

  Future<void> playRemoteStartupSound() async {
    if (remoteSoundPlayed) return;
    remoteSoundPlayed = true;
    try {
      final bytes = base64Decode(kStartupSoundBase64);
      final path =
          '${Directory.systemTemp.path}${Platform.pathSeparator}psr3_remote_startup.mp3';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      await remotePlayer.stop();
      await remotePlayer.setReleaseMode(ReleaseMode.stop);
      await remotePlayer.setVolume(1.0);
      await remotePlayer.play(
        DeviceFileSource(path),
        volume: 1.0,
      );
    } catch (e) {
      remoteSoundPlayed = false;
      if (mounted) {
        note('Не удалось воспроизвести звук Remote Play: $e');
      }
    }
  }

  Future<void> beginUpdate() async {
    final modeResult =
        await postJson('/api/update-mode', const <String, dynamic>{});
    if (!mounted) return;

    if (!modeResult.ok) {
      note(modeResult.message);
      return;
    }

    setState(() => consoleMode = 'update');

    final picked = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.any,
      dialogTitle: 'Выберите прошивку PSR3',
    );
    if (!mounted) return;
    if (picked == null || picked.files.single.path == null) {
      note('Файл прошивки не выбран');
      return;
    }

    final firmwareFile = File(picked.files.single.path!);
    final dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: surface,
        title: Text('Update Mode'),
        content: SizedBox(
          width: 380,
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 18),
              Expanded(child: Text('Отправка прошивки на консоль…')),
            ],
          ),
        ),
      ),
    );

    final result = await uploadFirmware(firmwareFile);

    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await dialog;

    if (!mounted) return;
    if (result.ok) {
      note('Прошивка отправлена. Консоль находится в Update Mode.');
    } else {
      note(result.message);
    }
  }

  Future<ApiResult> uploadFirmware(File file) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.postUrl(
        Uri.parse('$baseUrl/api/update/firmware'),
      );
      final length = await file.length();
      request.headers.contentType = ContentType.binary;
      request.headers.set(
        'X-Filename',
        Uri.encodeComponent(file.uri.pathSegments.last),
      );
      request.contentLength = length;
      await request.addStream(file.openRead());
      final response = await request.close().timeout(
        const Duration(minutes: 5),
      );
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ApiResult(
          false,
          'Ошибка прошивки: HTTP ${response.statusCode}',
          const <String, dynamic>{},
        );
      }
      return ApiResult(
        true,
        body.trim().isEmpty ? 'OK' : body.trim(),
        const <String, dynamic>{},
      );
    } on TimeoutException {
      return const ApiResult(
        false,
        'Истекло время отправки прошивки',
        <String, dynamic>{},
      );
    } on SocketException catch (e) {
      return ApiResult(
        false,
        'Нет связи с ESP32: ${e.message}',
        const <String, dynamic>{},
      );
    } catch (e) {
      return ApiResult(
        false,
        'Ошибка прошивки: $e',
        const <String, dynamic>{},
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> postCommand(String path) async {
    final result = await postJson(path, const <String, dynamic>{});
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
    statusTimer?.cancel();
    unawaited(remotePlayer.stop());
    remoteSoundPlayed = false;
    setState(() {
      chooseMode = true;
      streamMode = false;
      connected = false;
      mode = null;
      page = MainPage.system;
      consoleMode = 'unknown';
      consoleError = '—';
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

class RemoteLoadingDialog extends StatefulWidget {
  final VoidCallback onCancel;

  const RemoteLoadingDialog({super.key, required this.onCancel});

  @override
  State<RemoteLoadingDialog> createState() => _RemoteLoadingDialogState();
}

class _RemoteLoadingDialogState extends State<RemoteLoadingDialog> {
  int activeDot = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 380), (_) {
      if (mounted) setState(() => activeDot = (activeDot + 1) % 3);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Widget connectionDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: index == activeDot ? 14 : 11,
      height: index == activeDot ? 14 : 11,
      margin: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: index == activeDot
            ? Colors.white
            : const Color(0xFF6E7175),
        shape: BoxShape.circle,
        boxShadow: index == activeDot
            ? const [
                BoxShadow(
                  color: Color(0x77FFFFFF),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                constraints: const BoxConstraints(maxWidth: 820),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 26,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      const Text(
                        'Поиск PSR3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 31,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Это может занять несколько минут.',
                        style: TextStyle(
                          color: Color(0xFFAAAAAF),
                          fontSize: 19,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.desktop_windows_rounded,
                            color: Colors.white,
                            size: 52,
                          ),
                          const SizedBox(width: 42),
                          connectionDot(0),
                          connectionDot(1),
                          connectionDot(2),
                          const SizedBox(width: 42),
                          const Icon(
                            Icons.sports_esports_rounded,
                            color: Colors.white,
                            size: 64,
                          ),
                        ],
                      ),
                      const Spacer(flex: 2),
                      TextButton(
                        onPressed: widget.onCancel,
                        child: const Text(
                          'ОТМЕНИТЬ',
                          style: TextStyle(
                            color: greenSoft,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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

class DirectLoadingDialog extends StatefulWidget {
  final VoidCallback onCancel;

  const DirectLoadingDialog({super.key, required this.onCancel});

  @override
  State<DirectLoadingDialog> createState() => _DirectLoadingDialogState();
}

class _DirectLoadingDialogState extends State<DirectLoadingDialog> {
  bool bright = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 550), (_) {
      if (mounted) setState(() => bright = !bright);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: surface,
        title: const Text('Прямое подключение'),
        content: SizedBox(
          width: 420,
          height: 230,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                width: bright ? 96 : 82,
                height: bright ? 96 : 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bright
                      ? const Color(0x3328A966)
                      : const Color(0x221A6F48),
                ),
                child: const Icon(
                  Icons.wifi_rounded,
                  color: greenSoft,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Подключение к PSR3…',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Проверяем состояние консоли',
                style: TextStyle(color: muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('ОТМЕНИТЬ'),
          ),
        ],
      ),
    );
  }
}

class ModeCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const ModeCard({
    super.key,
    required this.icon,
    required this.title,
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
          height: 175,
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
                  color: const Color(0x33246B45),
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
          color: selected ? const Color(0x33246B45) : Colors.transparent,
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

class PingInfoRow extends StatelessWidget {
  final double? pingMs;

  const PingInfoRow({
    super.key,
    required this.pingMs,
  });

  int levelFor(double? value) {
    if (value == null) return 0;
    if (value <= 35) return 4;
    if (value <= 70) return 3;
    if (value <= 130) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final target = pingMs ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          const Expanded(
            child: Text('Пинг', style: TextStyle(color: muted)),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: target),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              final displayValue = pingMs == null ? null : value;
              return Row(
                children: [
                  SignalBars(level: levelFor(displayValue)),
                  const SizedBox(width: 9),
                  SizedBox(
                    width: 58,
                    child: Text(
                      displayValue == null
                          ? '—'
                          : '${displayValue.round()} ms',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class SignalBars extends StatelessWidget {
  final int level;

  const SignalBars({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (index) {
          final active = index < level;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            width: 5,
            height: 5.0 + index * 4.2,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: active ? greenSoft : const Color(0xFF344039),
              borderRadius: BorderRadius.circular(1.8),
              boxShadow: active
                  ? const [
                      BoxShadow(
                        color: Color(0x4478D39D),
                        blurRadius: 5,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}

class RemoteWavesPainter extends CustomPainter {
  const RemoteWavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < 8; i++) {
      final path = Path();
      final baseY = size.height * (0.26 + i * 0.065);
      final amp = 22.0 + i * 4;
      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += 8) {
        final y = baseY +
            math.sin((x / size.width * 6.283 * 1.55) + i * 0.62) * amp;
        path.lineTo(x, y);
      }
      paint.color = Color.fromRGBO(120, 211, 157, 0.18 - i * 0.012);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
).hasMatch(clean)) {
                  setDialogState(() => error = 'Введите ровно 4 цифры');
                  return;
                }
                Navigator.pop(dialogContext, clean);
              },
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

  void exitRemotePlay() {
    unawaited(remotePlayer.stop());
    setState(() {
      streamMode = false;
      chooseMode = true;
      connected = false;
      remoteSoundPlayed = false;
    });
  }

  Widget stream() {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): exitRemotePlay,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xFF050806),
          body: Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: RemoteWavesPainter()),
              ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, 0.15),
                      radius: 1.05,
                      colors: [
                        Color(0x2228A966),
                        Color(0x110F5D3B),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sports_esports_rounded,
                      size: 74,
                      color: greenSoft,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Remote Play',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Подключение установлено',
                      style: TextStyle(color: muted, fontSize: 15),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'ESC — выйти',
                      style: TextStyle(color: Color(0xFF657269), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
                  const Text('Прямое подключение', style: TextStyle(color: greenSoft)),
                  const SizedBox(height: 24),
                  NavItem(
                    icon: Icons.memory_rounded,
                    label: 'Система',
                    selected: page == MainPage.system,
                    onTap: () => setState(() => page = MainPage.system),
                  ),
                  if (!safeMode) ...[
                    const SizedBox(height: 8),
                    NavItem(
                      icon: Icons.settings_rounded,
                      label: 'Настройки',
                      selected: page == MainPage.settings,
                      onTap: () => setState(() => page = MainPage.settings),
                    ),
                  ],
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
                child: safeMode || page == MainPage.system
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
    final connectionPanel = Panel(
      title: 'Подключение',
      width: 410,
      child: Column(
        children: [
          InfoRow(label: 'Статус', value: connected ? 'Подключено' : 'Нет связи'),
          InfoRow(label: 'Режим', value: modeLabel),
          InfoRow(label: 'IP', value: ip),
          PingInfoRow(pingMs: pingMs),
          InfoRow(label: 'Прошивка', value: firmware),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => refreshInfo(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Обновить'),
            ),
          ),
        ],
      ),
    );

    final systemPanel = Panel(
      title: 'Система',
      width: 410,
      child: safeMode
          ? Column(
              children: [
                InfoRow(label: 'Свободная память', value: freeHeap),
                InfoRow(label: 'Ошибка', value: consoleError),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => postCommand('/api/restart'),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('Перезагрузка'),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                InfoRow(label: 'Свободная память', value: freeHeap),
                InfoRow(label: 'Крупнейший блок', value: largestBlock),
              ],
            ),
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [connectionPanel, systemPanel],
          ),
          if (safeMode) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: 836,
              child: FilledButton.icon(
                onPressed: beginUpdate,
                icon: const Icon(Icons.system_update_alt_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Update'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget settingsPage() {
    if (safeMode) return systemPage();

    return SingleChildScrollView(
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          Panel(
            title: 'Управление консолью',
            width: 430,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => postCommand('/api/restart'),
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Перезагрузка'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: beginUpdate,
                  icon: const Icon(Icons.system_update_alt_rounded),
                  label: const Text('Update'),
                ),
              ],
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

  void startStatusPolling() {
    statusTimer?.cancel();
    statusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && connected && mode == ConnectMode.esp32) {
        refreshInfo(silent: true);
      }
    });
  }

  Future<void> refreshInfo({bool silent = false}) async {

    final watch = Stopwatch()..start();
    final result = await getJson('/api/status');
    watch.stop();

    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        connected = false;
        pingMs = null;
      });
      if (!silent) note(result.message);
      return;
    }

    final data = result.data;
    setState(() {
      connected = true;
      pingMs = watch.elapsedMilliseconds.toDouble();
      firmware = field(data, 'firmware');
      freeHeap = formatMb(data['free_heap']);
      largestBlock = formatMb(data['largest_block']);
      final rawMode = field(data, 'mode');
      consoleMode = rawMode == '—' ? field(data, 'state') : rawMode;
      consoleError = field(data, 'error');
      if (safeMode) page = MainPage.system;
    });
  }

  String formatMb(dynamic value) {
    if (value == null) return '—';
    final raw = value is num
        ? value.toDouble()
        : double.tryParse(value.toString().replaceAll(RegExp(r'[^0-9.-]'), ''));
    if (raw == null) return '—';
    return '${(raw / (1024 * 1024)).toStringAsFixed(2)} МБ';
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

  Future<void> playRemoteStartupSound() async {
    if (remoteSoundPlayed) return;
    remoteSoundPlayed = true;
    try {
      final bytes = base64Decode(kStartupSoundBase64);
      final path =
          '${Directory.systemTemp.path}${Platform.pathSeparator}psr3_remote_startup.mp3';
      final file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      await remotePlayer.stop();
      await remotePlayer.setReleaseMode(ReleaseMode.stop);
      await remotePlayer.setVolume(1.0);
      await remotePlayer.play(
        DeviceFileSource(path),
        volume: 1.0,
      );
    } catch (e) {
      remoteSoundPlayed = false;
      if (mounted) {
        note('Не удалось воспроизвести звук Remote Play: $e');
      }
    }
  }

  Future<void> beginUpdate() async {
    final modeResult = await postJson('/api/update-mode', const <String, dynamic>{});
    if (!mounted) return;

    if (!modeResult.ok) {
      note(modeResult.message);
      return;
    }

    setState(() => consoleMode = 'update');

    final picked = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.any,
      dialogTitle: 'Выберите прошивку PSR3',
    );
    if (!mounted) return;
    if (picked == null || picked.files.single.path == null) {
      note('Файл прошивки не выбран');
      return;
    }

    final firmwareFile = File(picked.files.single.path!);
    final dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        backgroundColor: surface,
        title: Text('Update Mode'),
        content: SizedBox(
          width: 380,
          child: Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(width: 18),
              Expanded(child: Text('Отправка прошивки на консоль…')),
            ],
          ),
        ),
      ),
    );

    final result = await uploadFirmware(firmwareFile);

    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await dialog;

    if (!mounted) return;
    if (result.ok) {
      note('Прошивка отправлена. Консоль находится в Update Mode.');
    } else {
      note(result.message);
    }
  }

  Future<ApiResult> uploadFirmware(File file) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.postUrl(
        Uri.parse('$baseUrl/api/update/firmware'),
      );
      final length = await file.length();
      request.headers.contentType = ContentType.binary;
      request.headers.set(
        'X-Filename',
        Uri.encodeComponent(file.uri.pathSegments.last),
      );
      request.contentLength = length;
      await request.addStream(file.openRead());
      final response = await request.close().timeout(
        const Duration(minutes: 5),
      );
      final body = await utf8.decoder.bind(response).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ApiResult(
          false,
          'Ошибка прошивки: HTTP ${response.statusCode}',
          const <String, dynamic>{},
        );
      }
      return ApiResult(
        true,
        body.trim().isEmpty ? 'OK' : body.trim(),
        const <String, dynamic>{},
      );
    } on TimeoutException {
      return const ApiResult(
        false,
        'Истекло время отправки прошивки',
        <String, dynamic>{},
      );
    } on SocketException catch (e) {
      return ApiResult(
        false,
        'Нет связи с ESP32: ${e.message}',
        const <String, dynamic>{},
      );
    } catch (e) {
      return ApiResult(
        false,
        'Ошибка прошивки: $e',
        const <String, dynamic>{},
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> postCommand(String path) async {
    final result = await postJson(path, const <String, dynamic>{});
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
    statusTimer?.cancel();
    unawaited(remotePlayer.stop());
    remoteSoundPlayed = false;
    setState(() {
      chooseMode = true;
      streamMode = false;
      connected = false;
      mode = null;
      page = MainPage.system;
      consoleMode = 'unknown';
      consoleError = '—';
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

class RemoteLoadingDialog extends StatefulWidget {
  final VoidCallback onCancel;

  const RemoteLoadingDialog({super.key, required this.onCancel});

  @override
  State<RemoteLoadingDialog> createState() => _RemoteLoadingDialogState();
}

class _RemoteLoadingDialogState extends State<RemoteLoadingDialog> {
  int activeDot = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 380), (_) {
      if (mounted) setState(() => activeDot = (activeDot + 1) % 3);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Widget connectionDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: index == activeDot ? 14 : 11,
      height: index == activeDot ? 14 : 11,
      margin: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: index == activeDot
            ? Colors.white
            : const Color(0xFF6E7175),
        shape: BoxShape.circle,
        boxShadow: index == activeDot
            ? const [
                BoxShadow(
                  color: Color(0x77FFFFFF),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                constraints: const BoxConstraints(maxWidth: 820),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 26,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      const Text(
                        'Поиск PSR3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 31,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Это может занять несколько минут.',
                        style: TextStyle(
                          color: Color(0xFFAAAAAF),
                          fontSize: 19,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.desktop_windows_rounded,
                            color: Colors.white,
                            size: 52,
                          ),
                          const SizedBox(width: 42),
                          connectionDot(0),
                          connectionDot(1),
                          connectionDot(2),
                          const SizedBox(width: 42),
                          const Icon(
                            Icons.sports_esports_rounded,
                            color: Colors.white,
                            size: 64,
                          ),
                        ],
                      ),
                      const Spacer(flex: 2),
                      TextButton(
                        onPressed: widget.onCancel,
                        child: const Text(
                          'ОТМЕНИТЬ',
                          style: TextStyle(
                            color: greenSoft,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
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

class DirectLoadingDialog extends StatefulWidget {
  final VoidCallback onCancel;

  const DirectLoadingDialog({super.key, required this.onCancel});

  @override
  State<DirectLoadingDialog> createState() => _DirectLoadingDialogState();
}

class _DirectLoadingDialogState extends State<DirectLoadingDialog> {
  bool bright = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 550), (_) {
      if (mounted) setState(() => bright = !bright);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: surface,
        title: const Text('Прямое подключение'),
        content: SizedBox(
          width: 420,
          height: 230,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                width: bright ? 96 : 82,
                height: bright ? 96 : 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bright
                      ? const Color(0x3328A966)
                      : const Color(0x221A6F48),
                ),
                child: const Icon(
                  Icons.wifi_rounded,
                  color: greenSoft,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Подключение к PSR3…',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Проверяем состояние консоли',
                style: TextStyle(color: muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('ОТМЕНИТЬ'),
          ),
        ],
      ),
    );
  }
}

class ModeCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const ModeCard({
    super.key,
    required this.icon,
    required this.title,
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
          height: 175,
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
                  color: const Color(0x33246B45),
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
          color: selected ? const Color(0x33246B45) : Colors.transparent,
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

class PingInfoRow extends StatelessWidget {
  final double? pingMs;

  const PingInfoRow({
    super.key,
    required this.pingMs,
  });

  int levelFor(double? value) {
    if (value == null) return 0;
    if (value <= 35) return 4;
    if (value <= 70) return 3;
    if (value <= 130) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final target = pingMs ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          const Expanded(
            child: Text('Пинг', style: TextStyle(color: muted)),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: target),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              final displayValue = pingMs == null ? null : value;
              return Row(
                children: [
                  SignalBars(level: levelFor(displayValue)),
                  const SizedBox(width: 9),
                  SizedBox(
                    width: 58,
                    child: Text(
                      displayValue == null
                          ? '—'
                          : '${displayValue.round()} ms',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class SignalBars extends StatelessWidget {
  final int level;

  const SignalBars({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (index) {
          final active = index < level;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            width: 5,
            height: 5.0 + index * 4.2,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: active ? greenSoft : const Color(0xFF344039),
              borderRadius: BorderRadius.circular(1.8),
              boxShadow: active
                  ? const [
                      BoxShadow(
                        color: Color(0x4478D39D),
                        blurRadius: 5,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }
}

class RemoteWavesPainter extends CustomPainter {
  const RemoteWavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < 8; i++) {
      final path = Path();
      final baseY = size.height * (0.26 + i * 0.065);
      final amp = 22.0 + i * 4;
      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += 8) {
        final y = baseY +
            math.sin((x / size.width * 6.283 * 1.55) + i * 0.62) * amp;
        path.lineTo(x, y);
      }
      paint.color = Color.fromRGBO(120, 211, 157, 0.18 - i * 0.012);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
