import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

void main() => runApp(const Psr3App());

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
        scaffoldBackgroundColor: const Color(0xFF070B12),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF168BFF),
          secondary: Color(0xFF67B8FF),
          surface: Color(0xFF101824),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF101824),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
            side: BorderSide(color: Color(0xFF22324B)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF0B121D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

enum ConnectMode { none, esp32, remotePlay }
enum AppPage { dashboard, settings }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const blue = Color(0xFF168BFF);
  static const blueSoft = Color(0xFF67B8FF);
  static const border = Color(0xFF22324B);
  static const muted = Color(0xFF9CB0C9);
  static const green = Color(0xFF4BE29A);
  static const orange = Color(0xFFFFB45A);

  ConnectMode mode = ConnectMode.none;
  AppPage page = AppPage.dashboard;

  bool busy = false;
  bool connected = false;
  bool demoMode = false;

  String wifiName = 'PSR3';
  String ipAddress = '192.168.4.1';
  String remoteNetwork = '';
  String remoteCode = '';

  String headline = 'Choose a connection';
  String details = 'Connect directly to ESP32 or use the Remote Play pairing flow.';

  String freeHeap = '—';
  String largestBlock = '—';
  String wifiRssi = '—';
  String firmware = '—';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: mode == ConnectMode.none ? startScreen() : appShell(),
    );
  }

  Widget startScreen() {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0x22168BFF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: border),
                  ),
                  child: const Text(
                    'PSR3 for Windows',
                    style: TextStyle(
                      color: blueSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Connect your console',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Choose how the PC app should communicate with PSR3.',
                  style: TextStyle(color: muted, fontSize: 16),
                ),
                const SizedBox(height: 28),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final first = ConnectionCard(
                      icon: Icons.memory_rounded,
                      title: 'ESP32',
                      subtitle: 'Direct local connection to your PSR3 controller.',
                      bullets: const [
                        'Connect Windows to Wi-Fi “PSR3”',
                        'Default IP: 192.168.4.1',
                        'Status: /api/status',
                      ],
                      buttonText: 'Connect to ESP32',
                      onPressed: showEsp32Dialog,
                    );

                    final second = ConnectionCard(
                      icon: Icons.sports_esports_rounded,
                      title: 'Remote Play',
                      subtitle: 'Pair through a network and a code shown by PSR3.',
                      bullets: const [
                        'Choose the network manually',
                        'Enter exactly 4 digits',
                        'Continue into the PSR3 control center',
                      ],
                      buttonText: 'Use Remote Play',
                      onPressed: showRemoteDialog,
                    );

                    if (constraints.maxWidth < 760) {
                      return Column(
                        children: [
                          first,
                          const SizedBox(height: 18),
                          second,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: first),
                        const SizedBox(width: 18),
                        Expanded(child: second),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget appShell() {
    return SafeArea(
      child: Row(
        children: [
          Container(
            width: 250,
            margin: const EdgeInsets.all(18),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF101824),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PSR3',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  mode == ConnectMode.esp32 ? 'ESP32 session' : 'Remote Play session',
                  style: const TextStyle(color: muted),
                ),
                const SizedBox(height: 24),
                NavButton(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  selected: page == AppPage.dashboard,
                  onPressed: () => setState(() => page = AppPage.dashboard),
                ),
                const SizedBox(height: 10),
                NavButton(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  selected: page == AppPage.settings,
                  onPressed: () => setState(() => page = AppPage.settings),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B121D),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            connected ? Icons.circle : Icons.circle_outlined,
                            size: 12,
                            color: connected ? green : orange,
                          ),
                          const SizedBox(width: 8),
                          Text(connected ? 'Connected' : 'Not connected'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mode == ConnectMode.esp32
                            ? 'Wi-Fi: ' + wifiName + '\nIP: ' + ipAddress
                            : 'Network: ' + displayNetwork + '\nCode: ' + displayCode,
                        style: const TextStyle(color: muted, height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : returnToStart,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Back to start'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 18, 18, 18),
              child: Column(
                children: [
                  StatusHeader(
                    headline: headline,
                    details: details,
                    busy: busy,
                    connected: connected,
                    mode: mode == ConnectMode.esp32 ? 'ESP32' : 'Remote Play',
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      child: page == AppPage.dashboard
                          ? dashboard()
                          : settings(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get displayNetwork => remoteNetwork.isEmpty ? '—' : remoteNetwork;
  String get displayCode => remoteCode.isEmpty ? '—' : remoteCode;

  Widget dashboard() {
    return Wrap(
      spacing: 18,
      runSpacing: 18,
      children: [
        Panel(
          title: 'Connection',
          width: 400,
          child: Column(
            children: [
              InfoRow(
                label: 'Mode',
                value: mode == ConnectMode.esp32 ? 'ESP32' : 'Remote Play',
              ),
              InfoRow(
                label: 'Status',
                value: connected ? 'Connected' : 'Disconnected',
              ),
              InfoRow(
                label: 'Target',
                value: mode == ConnectMode.esp32
                    ? 'http://' + ipAddress + '/api/status'
                    : displayNetwork,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : reconnect,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reconnect'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : refreshDiagnostics,
                      icon: const Icon(Icons.analytics_rounded),
                      label: const Text('Refresh'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Panel(
          title: 'Diagnostics',
          width: 400,
          child: Column(
            children: [
              InfoRow(label: 'Free heap', value: freeHeap),
              InfoRow(label: 'Largest block', value: largestBlock),
              InfoRow(label: 'Wi-Fi RSSI', value: wifiRssi),
              InfoRow(label: 'Firmware', value: firmware),
            ],
          ),
        ),
        Panel(
          title: 'Quick actions',
          width: 400,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ActionChip(
                avatar: const Icon(Icons.power_settings_new_rounded, size: 18),
                label: const Text('Power'),
                onPressed: () => note('Power API command is the next firmware step.'),
              ),
              ActionChip(
                avatar: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Restart'),
                onPressed: () => note('Restart API command is the next firmware step.'),
              ),
              ActionChip(
                avatar: const Icon(Icons.system_update_alt_rounded, size: 18),
                label: const Text('Update Mode'),
                onPressed: () => note('Update Mode is reserved for firmware updates.'),
              ),
              ActionChip(
                avatar: const Icon(Icons.tv_rounded, size: 18),
                label: const Text('Recovery over AV'),
                onPressed: () => note('Recovery stays on the console and appears on the TV over AV.'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget settings() {
    return Wrap(
      spacing: 18,
      runSpacing: 18,
      children: [
        Panel(
          title: 'Connection settings',
          width: 500,
          child: Column(
            children: [
              if (mode == ConnectMode.esp32) ...[
                TextFormField(
                  initialValue: wifiName,
                  decoration: const InputDecoration(labelText: 'Wi-Fi network'),
                  onChanged: (value) => wifiName = value,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: ipAddress,
                  decoration: const InputDecoration(labelText: 'ESP32 IP address'),
                  onChanged: (value) => ipAddress = value,
                ),
              ] else ...[
                TextFormField(
                  initialValue: remoteNetwork,
                  decoration: const InputDecoration(labelText: 'Remote Play network'),
                  onChanged: (value) => remoteNetwork = value,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: remoteCode,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    labelText: '4-digit confirmation code',
                    counterText: '',
                  ),
                  onChanged: (value) => remoteCode = value,
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : reconnect,
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Apply and reconnect'),
                ),
              ),
            ],
          ),
        ),
        Panel(
          title: 'Testing',
          width: 360,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: demoMode,
            title: const Text('Demo mode'),
            subtitle: const Text(
              'Preview the connected UI when the real console is unavailable.',
            ),
            onChanged: (value) => setState(() => demoMode = value),
          ),
        ),
        Panel(
          title: 'Defaults',
          width: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Wi-Fi: PSR3'),
              const SizedBox(height: 8),
              const Text('IP: 192.168.4.1'),
              const SizedBox(height: 8),
              const Text('Endpoint: /api/status'),
              const SizedBox(height: 8),
              const Text('Remote Play code: exactly 4 digits'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: restoreDefaults,
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Restore defaults'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> showEsp32Dialog() async {
    final wifi = TextEditingController(text: wifiName);
    final ip = TextEditingController(text: ipAddress);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Connect to ESP32'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'First connect Windows to Wi-Fi “PSR3”, then confirm the local IP.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: wifi,
                decoration: const InputDecoration(labelText: 'Wi-Fi network'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ip,
                decoration: const InputDecoration(labelText: 'ESP32 IP address'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newWifi = wifi.text.trim().isEmpty ? 'PSR3' : wifi.text.trim();
              final newIp = ip.text.trim().isEmpty ? '192.168.4.1' : ip.text.trim();
              Navigator.pop(dialogContext);
              connectEsp32(newWifi, newIp);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    wifi.dispose();
    ip.dispose();
  }

  Future<void> showRemoteDialog() async {
    final network = TextEditingController(text: remoteNetwork);
    final code = TextEditingController(text: remoteCode);
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Remote Play pairing'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose the network manually and enter the 4-digit code shown on PSR3.',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: network,
                    decoration: const InputDecoration(labelText: 'Network name'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: code,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: '4-digit confirmation code',
                      counterText: '',
                      errorText: error,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = code.text.trim();
                  if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                    setDialogState(() => error = 'Enter exactly 4 digits');
                    return;
                  }
                  final selectedNetwork = network.text.trim();
                  Navigator.pop(dialogContext);
                  connectRemote(selectedNetwork, value);
                },
                child: const Text('Pair'),
              ),
            ],
          ),
        );
      },
    );

    network.dispose();
    code.dispose();
  }

  Future<void> connectEsp32(String wifi, String ip) async {
    setState(() {
      mode = ConnectMode.esp32;
      page = AppPage.dashboard;
      wifiName = wifi;
      ipAddress = ip;
      busy = true;
      connected = false;
      headline = 'Connecting to ESP32';
      details = 'GET http://' + ip + '/api/status over Wi-Fi “' + wifi + '”…';
    });

    final result = await probeStatus(ip);
    if (!mounted) return;

    setState(() {
      busy = false;
      connected = result.ok || demoMode;
      headline = result.ok
          ? 'ESP32 connected'
          : demoMode
              ? 'Demo mode active'
              : 'ESP32 connection failed';
      details = result.message;

      if (demoMode && !result.ok) {
        freeHeap = 'Demo';
        largestBlock = 'Demo';
        wifiRssi = '-48 dBm';
        firmware = 'Demo';
      }
    });

    if (!result.ok && !demoMode) note(result.message);
  }

  Future<ProbeResult> probeStatus(String ip) async {
    final uri = Uri.parse('http://' + ip + '/api/status');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);

    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(const Duration(seconds: 5));
      await response.drain<List<int>>();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ProbeResult(
          true,
          'PSR3 answered at ' + uri.toString() + ' with HTTP ' + response.statusCode.toString() + '.',
        );
      }

      return ProbeResult(
        false,
        'PSR3 answered, but /api/status returned HTTP ' + response.statusCode.toString() + '.',
      );
    } on TimeoutException {
      return const ProbeResult(
        false,
        'Connection timed out. Check Wi-Fi “PSR3”, IP 192.168.4.1 and /api/status.',
      );
    } on SocketException catch (e) {
      return ProbeResult(
        false,
        'Could not reach ' + uri.toString() + ': ' + e.message,
      );
    } catch (e) {
      return ProbeResult(false, 'Connection error: ' + e.toString());
    } finally {
      client.close(force: true);
    }
  }

  Future<void> connectRemote(String network, String code) async {
    setState(() {
      mode = ConnectMode.remotePlay;
      page = AppPage.dashboard;
      remoteNetwork = network;
      remoteCode = code;
      busy = true;
      connected = false;
      headline = 'Pairing Remote Play';
      details = 'Checking network name and 4-digit confirmation code…';
    });

    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final validNetwork = network.isNotEmpty;
    final validCode = RegExp(r'^\d{4}$').hasMatch(code);

    setState(() {
      busy = false;
      connected = (validNetwork && validCode) || demoMode;
      headline = connected ? 'Remote Play ready' : 'Pairing failed';

      if (!validNetwork) {
        details = 'Choose a network first.';
      } else if (!validCode) {
        details = 'The confirmation code must contain exactly 4 digits.';
      } else {
        details = 'Pairing data accepted. The real Remote Play transport can be added next.';
      }

      freeHeap = 'N/A';
      largestBlock = 'N/A';
      wifiRssi = 'N/A';
      firmware = 'N/A';
    });
  }

  Future<void> reconnect() async {
    if (mode == ConnectMode.esp32) {
      await connectEsp32(wifiName, ipAddress);
    } else if (mode == ConnectMode.remotePlay) {
      await connectRemote(remoteNetwork, remoteCode);
    }
  }

  Future<void> refreshDiagnostics() async {
    if (!connected) {
      note('Connect to PSR3 first.');
      return;
    }

    if (mode == ConnectMode.esp32) {
      setState(() {
        headline = 'Refreshing diagnostics';
        details = 'Checking /api/status…';
      });

      final result = await probeStatus(ipAddress);
      if (!mounted) return;

      setState(() {
        headline = result.ok ? 'Diagnostics refreshed' : 'Refresh failed';
        details = result.message;
        freeHeap = demoMode ? 'Demo' : (result.ok ? 'API online' : '—');
        largestBlock = demoMode ? 'Demo' : (result.ok ? 'Awaiting JSON fields' : '—');
        wifiRssi = demoMode ? '-48 dBm' : (result.ok ? 'Awaiting JSON fields' : '—');
        firmware = demoMode ? 'Demo' : (result.ok ? 'Awaiting JSON fields' : '—');
      });
    } else {
      note('Remote Play diagnostics are not defined yet.');
    }
  }

  void restoreDefaults() {
    setState(() {
      wifiName = 'PSR3';
      ipAddress = '192.168.4.1';
      remoteNetwork = '';
      remoteCode = '';
    });
    note('Defaults restored.');
  }

  void returnToStart() {
    setState(() {
      mode = ConnectMode.none;
      connected = false;
      busy = false;
      headline = 'Choose a connection';
      details = 'Connect directly to ESP32 or use the Remote Play pairing flow.';
    });
  }

  void note(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class ProbeResult {
  final bool ok;
  final String message;

  const ProbeResult(this.ok, this.message);
}

class ConnectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> bullets;
  final String buttonText;
  final VoidCallback onPressed;

  const ConnectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bullets,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0x22168BFF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: const Color(0xFF67B8FF), size: 30),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF9CB0C9), height: 1.45),
            ),
            const SizedBox(height: 18),
            for (final bullet in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 17,
                      color: Color(0xFF67B8FF),
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text(bullet)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const NavButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0x22168BFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF168BFF)
                : const Color(0xFF22324B),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF67B8FF) : Colors.white,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? const Color(0xFF67B8FF) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusHeader extends StatelessWidget {
  final String headline;
  final String details;
  final bool busy;
  final bool connected;
  final String mode;

  const StatusHeader({
    super.key,
    required this.headline,
    required this.details,
    required this.busy,
    required this.connected,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x22168BFF), Color(0x11070B12)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF22324B)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  details,
                  style: const TextStyle(
                    color: Color(0xFF9CB0C9),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (busy)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: connected
                    ? const Color(0x224BE29A)
                    : const Color(0x22FFB45A),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                connected ? mode + ' connected' : mode + ' standby',
                style: TextStyle(
                  color: connected
                      ? const Color(0xFF4BE29A)
                      : const Color(0xFFFFB45A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
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
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF9CB0C9)),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
