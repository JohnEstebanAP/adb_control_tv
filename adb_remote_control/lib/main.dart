// Copyright 2026 Pepe Tiebosch (byme.dev). All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_adb/flutter_adb.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adb_remote_control.dart';
import 'adb_terminal.dart';
import 'example_storage.dart';

final exampleStorageProvider = Provider<ExampleStorage>(
  (ref) => ExampleStorage(),
);

final adbCryptoProvider = FutureProvider<AdbCrypto>((ref) async {
  return ref.read(exampleStorageProvider).loadOrCreateCrypto();
});

class SavedDevicesNotifier extends AsyncNotifier<List<SavedAdbDevice>> {
  ExampleStorage get _storage => ref.read(exampleStorageProvider);

  @override
  Future<List<SavedAdbDevice>> build() {
    return _storage.loadSavedDevices();
  }

  Future<void> saveDevice({
    required String ip,
    required int port,
    String? label,
  }) async {
    await _storage.saveDevice(ip: ip, port: port, label: label);
    state = AsyncData(await _storage.loadSavedDevices());
  }

  Future<void> deleteDevice(String id) async {
    await _storage.deleteDevice(id);
    state = AsyncData(await _storage.loadSavedDevices());
  }
}

final savedDevicesProvider =
    AsyncNotifierProvider<SavedDevicesNotifier, List<SavedAdbDevice>>(
      SavedDevicesNotifier.new,
    );

class AdbConnectionNotifier extends Notifier<AdbConnection?> {
  @override
  AdbConnection? build() {
    return null;
  }

  Future<void> setConnection(String ip, int port) async {
    await state?.disconnect();
    final crypto = await ref.read(adbCryptoProvider.future);
    state = AdbConnection(ip, port, crypto, verbose: true);
    await state?.connect();
  }

  void disconnect() {
    state?.disconnect();
    state = null;
  }
}

final adbConnectionProvider =
    NotifierProvider<AdbConnectionNotifier, AdbConnection?>(
      AdbConnectionNotifier.new,
    );

enum PairingStatus { idle, pairing, success, error }

class AdbPairingNotifier extends Notifier<PairingStatus> {
  @override
  PairingStatus build() {
    return PairingStatus.idle;
  }

  Future<void> pair(String ip, int port, String code) async {
    state = PairingStatus.pairing;
    try {
      final crypto = await ref.read(adbCryptoProvider.future);
      final result = await AdbPairing.pair(
        ip,
        port,
        code,
        crypto,
        verbose: true,
      );
      state = result ? PairingStatus.success : PairingStatus.error;
    } catch (_) {
      state = PairingStatus.error;
    }
  }

  void reset() {
    state = PairingStatus.idle;
  }
}

final adbPairingProvider = NotifierProvider<AdbPairingNotifier, PairingStatus>(
  AdbPairingNotifier.new,
);

enum QrPairingStatus { idle, pairing, success, error }

final class QrPairingSession {
  const QrPairingSession({
    this.status = QrPairingStatus.idle,
    this.qrData,
    this.result,
  });

  final QrPairingStatus status;
  final AdbQrPairingData? qrData;
  final AdbPairingResult? result;
}

class QrPairingNotifier extends Notifier<QrPairingSession> {
  @override
  QrPairingSession build() {
    return const QrPairingSession();
  }

  void reset() {
    state = const QrPairingSession();
  }
}

final qrPairingProvider = NotifierProvider<QrPairingNotifier, QrPairingSession>(
  QrPairingNotifier.new,
);

class AdbStreamNotifier extends AsyncNotifier<AdbStream?> {
  @override
  FutureOr<AdbStream?> build() async {
    final connection = ref.watch(adbConnectionProvider);
    if (connection == null) return null;

    return await connection.openShell();
  }
}

final adbStreamProvider = AsyncNotifierProvider<AdbStreamNotifier, AdbStream?>(
  AdbStreamNotifier.new,
);

void main() {
  final ProviderContainer container = ProviderContainer();
  WidgetsFlutterBinding.ensureInitialized();
  runApp(UncontrolledProviderScope(container: container, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control TV',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9B8CFF),
          brightness: Brightness.dark,
          surface: const Color(0xFF151D32),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1020),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B1020),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF151D32),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF29344C)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF9B8CFF), width: 1.5),
          ),
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key});

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _ipController = TextEditingController(
    text: '127.0.0.1',
  );
  final TextEditingController _portController = TextEditingController(
    text: '5555',
  );
  final TextEditingController _pairingPortController = TextEditingController();
  final TextEditingController _pairingCodeController = TextEditingController();

  bool _showPairing = false;
  bool _isCreatingConnection = false;

  void _toggleCodePairing() {
    setState(() {
      _showPairing = !_showPairing;
      if (_showPairing) {
        ref.read(qrPairingProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _pairingPortController.dispose();
    _pairingCodeController.dispose();
    super.dispose();
  }

  Future<void> _connectToCurrentTarget() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreatingConnection = true);
    try {
      final ip = _ipController.text;
      final port = int.parse(_portController.text);
      await ref.read(adbConnectionProvider.notifier).setConnection(ip, port);
      await ref
          .read(savedDevicesProvider.notifier)
          .saveDevice(ip: ip, port: port);
      unawaited(_refreshSavedDeviceLabel(ip, port));
    } finally {
      if (mounted) {
        setState(() => _isCreatingConnection = false);
      }
    }
  }

  Future<void> _pairCurrentTarget() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_pairingPortController.text.isEmpty ||
        _pairingCodeController.text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Ingresa el puerto y el código de emparejamiento'),
        ),
      );
      return;
    }

    await ref
        .read(adbPairingProvider.notifier)
        .pair(
          _ipController.text,
          int.parse(_pairingPortController.text),
          _pairingCodeController.text,
        );
    if (!mounted) return;

    final finalStatus = ref.read(adbPairingProvider);
    if (finalStatus == PairingStatus.success) {
      await ref
          .read(savedDevicesProvider.notifier)
          .saveDevice(
            ip: _ipController.text,
            port: int.tryParse(_portController.text) ?? 5555,
          );
      messenger.showSnackBar(
        const SnackBar(content: Text('Emparejamiento correcto')),
      );
      setState(() => _showPairing = false);
    } else if (finalStatus == PairingStatus.error) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo emparejar el televisor')),
      );
    }
  }

  void _loadSavedDevice(SavedAdbDevice device) {
    _ipController.text = device.ip;
    _portController.text = device.port.toString();
  }

  Future<void> _refreshSavedDeviceLabel(String ip, int port) async {
    try {
      final connection = ref.read(adbConnectionProvider);
      if (connection == null) {
        return;
      }
      final stream = await connection.openShell();
      final command =
          'getprop ro.product.manufacturer && getprop ro.product.model;exit\n';
      await stream.writeString(command);
      final combined = await stream.onPayload
          .fold('', (prev, chunk) => prev + utf8.decode(chunk))
          .timeout(const Duration(seconds: 10), onTimeout: () => '');
      stream.close();
      // Strip the echoed command prefix if present
      final output = combined.contains(command.trim())
          ? combined.split(command.trim()).last
          : combined;
      final parts = output.trim().split('\n');
      final manufacturer = parts.isNotEmpty ? parts[0].trim() : '';
      final model = parts.length > 1 ? parts[1].trim() : '';

      final label = _buildDeviceLabel(manufacturer, model, ip, port);
      await ref
          .read(savedDevicesProvider.notifier)
          .saveDevice(ip: ip, port: port, label: label);
    } catch (e) {
      // Best-effort label enrichment for the example UI.
      debugPrint('Failed to refresh device label for $ip:$port, error: $e');
    }
  }

  String _buildDeviceLabel(
    String manufacturer,
    String model,
    String ip,
    int port,
  ) {
    final cleanManufacturer = manufacturer.trim();
    final cleanModel = model.trim();
    final combined = [cleanManufacturer, cleanModel]
        .where((value) => value.isNotEmpty)
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (combined.isEmpty) {
      return '$ip:$port';
    }
    return '$combined ($ip)';
  }

  Widget _buildConnectionControls(AsyncValue<AdbCrypto> cryptoAsync) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF151D32),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tv_rounded, color: Color(0xFF9B8CFF), size: 25),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conecta tu televisor',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Usa ADB inalámbrico para empezar a controlarlo.',
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          cryptoAsync.when(
            data: (crypto) => Text(
              'Clave segura: ${crypto.adbKeyName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => Text('Failed to load stored key: $error'),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextFormField(
                        controller: _ipController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'IP del televisor',
                          labelText: 'IP del televisor',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa una dirección IP válida';
                          }
                          if (!RegExp(
                            r'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$',
                          ).hasMatch(value)) {
                            return 'Ingresa una dirección IP válida';
                          }
                          return null;
                        },
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: TextFormField(
                        controller: _portController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Puerto ADB',
                          labelText: 'Puerto ADB',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa un puerto válido';
                          }
                          if (int.tryParse(value) == null ||
                              int.parse(value) < 1 ||
                              int.parse(value) > 65535) {
                            return 'Ingresa un puerto entre 1 y 65535';
                          }
                          return null;
                        },
                      ),
                    ),
                    StreamBuilder<bool>(
                      stream: ref
                          .watch(adbConnectionProvider)
                          ?.onConnectionChanged,
                      initialData: false,
                      builder: (context, snapshot) {
                        final connection = ref.watch(adbConnectionProvider);
                        final isConnected = snapshot.data ?? false;
                        return ElevatedButton(
                          onPressed:
                              cryptoAsync.isLoading || _isCreatingConnection
                              ? null
                              : () async {
                                  if (connection != null) {
                                    ref
                                        .read(adbConnectionProvider.notifier)
                                        .disconnect();
                                  } else {
                                    await _connectToCurrentTarget();
                                  }
                                },
                          child: _isCreatingConnection
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  connection != null
                                      ? (isConnected
                                            ? 'Desconectar'
                                            : 'Cancelar')
                                      : 'Conectar',
                                ),
                        );
                      },
                    ),
                    OutlinedButton(
                      onPressed: _toggleCodePairing,
                      child: Text(
                        _showPairing
                            ? 'Ocultar emparejamiento'
                            : 'Emparejar con código',
                      ),
                    ),
                  ],
                ),
                if (_showPairing) ...[
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: 180,
                        child: TextFormField(
                          controller: _pairingPortController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Puerto de emparejamiento',
                            labelText: 'Puerto de emparejamiento',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: TextFormField(
                          controller: _pairingCodeController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Código de 6 dígitos',
                            labelText: 'Código de emparejamiento',
                          ),
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final status = ref.watch(adbPairingProvider);
                          return ElevatedButton(
                            onPressed:
                                status == PairingStatus.pairing ||
                                    cryptoAsync.isLoading
                                ? null
                                : _pairCurrentTarget,
                            child: status == PairingStatus.pairing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Emparejar'),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedConnections(
    AsyncValue<List<SavedAdbDevice>> savedDevicesAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dispositivos guardados',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        savedDevicesAsync.when(
          data: (devices) {
            if (devices.isEmpty) {
              return const Text('Aún no hay dispositivos guardados.');
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: devices.map((device) {
                return InputChip(
                  label: Text(device.label),
                  onPressed: () => _loadSavedDevice(device),
                  onDeleted: () => ref
                      .read(savedDevicesProvider.notifier)
                      .deleteDevice(device.id),
                  tooltip: '${device.ip}:${device.port}',
                );
              }).toList(),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (error, stack) =>
              Text('Failed to load saved connections: $error'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cryptoAsync = ref.watch(adbCryptoProvider);
    final savedDevicesAsync = ref.watch(savedDevicesProvider);
    final activeConnection = ref.watch(adbConnectionProvider);

    final terminal = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: ref
          .watch(adbStreamProvider)
          .maybeWhen(
            data: (adbStream) {
              if (adbStream == null) {
                return const Center(
                  child: Text('Press Connect to start ADB session'),
                );
              }
              return AdbTerminal(
                stream: adbStream,
                onDisconnect: () =>
                    ref.read(adbConnectionProvider.notifier).disconnect(),
              );
            },
            loading: () => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Connecting to ADB...'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(adbConnectionProvider.notifier).disconnect(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            error: (error, stack) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.read(adbConnectionProvider.notifier).disconnect(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
            orElse: () => const SizedBox(),
          ),
    );

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<bool>(
          stream: ref.watch(adbConnectionProvider)?.onConnectionChanged,
          initialData: false,
          builder: (context, snapshot) {
            final connection = ref.watch(adbConnectionProvider);
            final connected = connection != null && (snapshot.data ?? false);
            final status = connection == null
                ? 'Sin conexión'
                : connected
                ? 'Conectado · ${connection.ip}'
                : 'Conectando…';
            return Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B8CFF).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.settings_remote_rounded,
                    color: Color(0xFFB7ADFF),
                    size: 21,
                  ),
                ),
                const SizedBox(width: 11),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'CONTROL TV',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: connected
                                ? const Color(0xFF59E1C0)
                                : Colors.white38,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (activeConnection != null) {
              return const AdbRemoteControl();
            }
            final showSidebar = constraints.maxWidth >= 1100;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConnectionControls(cryptoAsync),
                  const SizedBox(height: 20),
                  if (showSidebar)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 260,
                          child: _buildSavedConnections(savedDevicesAsync),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: SizedBox(
                            height: 240,
                            child: Center(child: terminal),
                          ),
                        ),
                      ],
                    )
                  else
                    _buildSavedConnections(savedDevicesAsync),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
