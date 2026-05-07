import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const AdbRemoteControlApp());
}

class AdbRemoteControlApp extends StatelessWidget {
  const AdbRemoteControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ADB Remote Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const RemoteControlPage(),
    );
  }
}

class RemoteControlPage extends StatefulWidget {
  const RemoteControlPage({super.key});

  @override
  State<RemoteControlPage> createState() => _RemoteControlPageState();
}

class _RemoteControlPageState extends State<RemoteControlPage> {
  final TextEditingController _serverController = TextEditingController(
    text: 'http://192.168.0.100:8080',
  );

  bool _isLoading = false;
  String _status = 'Listo';

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _sendKey(String key) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _status = 'Enviando: $key';
    });

    try {
      final baseUrl = _serverController.text.trim();
      final uri = Uri.parse('$baseUrl/key');

      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'key': key}),
      );

      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _status = 'Comando enviado: $key';
        });
      } else {
        setState(() {
          _status = 'Error ${response.statusCode}: ${response.body}';
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _status = 'Error: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _status = 'Probando conexión...';
    });

    try {
      final baseUrl = _serverController.text.trim();
      final uri = Uri.parse('$baseUrl/health');

      final response = await http.get(uri);

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _status = 'Conectado correctamente';
        });
      } else {
        setState(() {
          _status = 'Servidor respondió: ${response.statusCode}';
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _status = 'No se pudo conectar: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _remoteButton({
    required IconData icon,
    required String label,
    required String keyValue,
  }) {
    return SizedBox(
      width: 90,
      height: 70,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _sendKey(keyValue),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon), const SizedBox(height: 4), Text(label)],
        ),
      ),
    );
  }

  Widget _emptySpace() {
    return const SizedBox(width: 90, height: 70);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ADB Remote Control')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _serverController,
                decoration: const InputDecoration(
                  labelText: 'Servidor',
                  hintText: 'http://192.168.0.100:8080',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _testConnection,
                  icon: const Icon(Icons.wifi),
                  label: const Text('Probar conexión'),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _emptySpace(),
                  _remoteButton(
                    icon: Icons.keyboard_arrow_up,
                    label: 'Arriba',
                    keyValue: 'up',
                  ),
                  _emptySpace(),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _remoteButton(
                    icon: Icons.keyboard_arrow_left,
                    label: 'Izq',
                    keyValue: 'left',
                  ),
                  const SizedBox(width: 12),
                  _remoteButton(
                    icon: Icons.radio_button_checked,
                    label: 'OK',
                    keyValue: 'ok',
                  ),
                  const SizedBox(width: 12),
                  _remoteButton(
                    icon: Icons.keyboard_arrow_right,
                    label: 'Der',
                    keyValue: 'right',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _emptySpace(),
                  _remoteButton(
                    icon: Icons.keyboard_arrow_down,
                    label: 'Abajo',
                    keyValue: 'down',
                  ),
                  _emptySpace(),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _remoteButton(
                    icon: Icons.arrow_back,
                    label: 'Atrás',
                    keyValue: 'back',
                  ),
                  const SizedBox(width: 16),
                  _remoteButton(
                    icon: Icons.home,
                    label: 'Home',
                    keyValue: 'home',
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
