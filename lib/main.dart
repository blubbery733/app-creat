import 'package:flutter/material.dart';

void main() {
  runApp(const Psr3App());
}

class Psr3App extends StatelessWidget {
  const Psr3App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PSR3 PC App',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0E1116),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4DA3FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool mockMode = true;
  bool connected = false;
  bool remotePlay = false;
  String ipAddress = '192.168.4.1';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 220,
              padding: const EdgeInsets.all(18),
              color: const Color(0xFF151A22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PSR3',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'PC App v0.1',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 28),
                  _NavItem(icon: Icons.dashboard, label: 'Dashboard'),
                  _NavItem(icon: Icons.gamepad, label: 'Remote Play'),
                  _NavItem(icon: Icons.memory, label: 'Diagnostics'),
                  _NavItem(icon: Icons.settings, label: 'Settings'),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        connected ? Icons.circle : Icons.circle_outlined,
                        size: 12,
                        color: connected ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(connected ? 'Connected' : 'Offline'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PSR3 Control Center',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Companion app for the ESP32-based PSR3 console',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      children: [
                        _Card(
                          title: 'Connection',
                          width: 360,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                initialValue: ipAddress,
                                decoration: const InputDecoration(
                                  labelText: 'PSR3 IP address',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (value) => ipAddress = value,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          connected = mockMode;
                                        });
                                      },
                                      icon: const Icon(Icons.link),
                                      label: const Text('Connect'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          connected = false;
                                        });
                                      },
                                      icon: const Icon(Icons.link_off),
                                      label: const Text('Disconnect'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: mockMode,
                                title: const Text('Mock Mode'),
                                subtitle: const Text(
                                  'Use the app without a real ESP32 connection',
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    mockMode = value;
                                    if (!value) connected = false;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        _Card(
                          title: 'Remote Play',
                          width: 360,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: remotePlay,
                                title: const Text('Enable Remote Play'),
                                subtitle: const Text(
                                  'Future stream and control bridge for PSR3',
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    remotePlay = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              const ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.sports_esports),
                                title: Text('Gamepad Plus'),
                                subtitle: Text('Controller integration placeholder'),
                              ),
                            ],
                          ),
                        ),
                        _Card(
                          title: 'Diagnostics',
                          width: 360,
                          child: const Column(
                            children: [
                              _DiagRow(label: 'Free heap', value: '—'),
                              _DiagRow(label: 'Largest block', value: '—'),
                              _DiagRow(label: 'Wi-Fi RSSI', value: '—'),
                              _DiagRow(label: 'Firmware', value: '—'),
                            ],
                          ),
                        ),
                        _Card(
                          title: 'Planned protocol',
                          width: 360,
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• HTTP for commands and status'),
                              SizedBox(height: 6),
                              Text('• WebSocket for live updates'),
                              SizedBox(height: 6),
                              Text('• Recovery stays on TV over AV'),
                              SizedBox(height: 6),
                              Text('• Update Mode planned for firmware updates'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final double width;

  const _Card({
    required this.title,
    required this.child,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        color: const Color(0xFF171D26),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  final String label;
  final String value;

  const _DiagRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
  }
}
