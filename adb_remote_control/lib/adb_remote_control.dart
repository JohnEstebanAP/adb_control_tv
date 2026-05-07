import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'app_list_screen.dart';
import 'direction_button.dart';
import 'key_codes.dart';
import 'main.dart';

class AdbRemoteControl extends ConsumerStatefulWidget {
  const AdbRemoteControl({super.key});

  @override
  ConsumerState<AdbRemoteControl> createState() => _AdbRemoteControlState();
}

class _AdbRemoteControlState extends ConsumerState<AdbRemoteControl> {
  final SpeechToText _speechToText = SpeechToText();
  bool _isSpeechInitialized = false;

  @override
  void initState() {
    _initSpeech();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(adbConnectionProvider) != null;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 3),
          controlButtons(isConnected, ref),
          const SizedBox(height: 24),
          homeControl(isConnected, ref),
          const SizedBox(height: 24),
          volumenControl(isConnected, ref),
          const SizedBox(height: 24),
          appsControl(isConnected, ref), // <-- NUEVA FILA DE APPS
          const SizedBox(height: 24),
          otherControls(isConnected, ref),
          ElevatedButton.icon(
            icon: const Icon(Icons.list),
            label: const Text('Ver todas las Apps'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AppListScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  void _initSpeech() async {
    _isSpeechInitialized = await _speechToText.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _sendCommand(WidgetRef ref, String command) async {
    final connection = ref.read(adbConnectionProvider);
    if (connection == null) return;

    try {
      // Abrimos un shell temporal para enviar el comando
      final stream = await connection.openShell();
      await stream.writeString('$command\n');
      // Cerramos el stream tras enviar el comando
      stream.close();
    } catch (e) {
      debugPrint('Error enviando comando ADB: $e');
    }
  }

  void _startListening(WidgetRef ref) async {
    if (!_isSpeechInitialized) return;

    await _speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          // Cuando terminas de hablar, enviamos el texto al TV
          _sendVoiceSearch(ref, result.recognizedWords);
        }
      },
    );
  }

  Future<void> _sendVoiceSearch(WidgetRef ref, String query) async {
    // Comando para abrir la búsqueda del TV con el texto reconocido
    print("MICROFONO: $query");
    final command =
        'am start -a android.intent.action.SEARCH --es query "$query"';
    final connection = ref.read(adbConnectionProvider);
    if (connection != null) {
      final stream = await connection.openShell();
      await stream.writeString('$command\n');
      stream.close();
    }
  }

  Column controlButtons(bool isConnected, WidgetRef ref) {
    return Column(
      children: [
        // Botón Arriba
        DirectionButton(
          icon: Icons.arrow_drop_up,
          onAction: isConnected
              ? () => _sendCommand(ref, KeyCodes.dpadUp.adbCommand)
              : null,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón Izquierda
            DirectionButton(
              icon: Icons.arrow_left,
              onAction: isConnected
                  ? () => _sendCommand(ref, KeyCodes.dpadLeft.adbCommand)
                  : null,
            ),
            const SizedBox(width: 8), // Espacio central
            // BOTÓN ENTER / OK (Keyevent 66)
            DirectionButton(
              icon: Icons.circle, // O usar Icons.check_circle
              onAction: isConnected
                  ? () => _sendCommand(ref, KeyCodes.dpadCenter.adbCommand)
                  : null,
            ),
            const SizedBox(width: 8),
            // Botón Derecha
            DirectionButton(
              icon: Icons.arrow_right,
              onAction: isConnected
                  ? () => _sendCommand(ref, KeyCodes.dpadRight.adbCommand)
                  : null,
            ),
          ],
        ),
        // Botón Abajo
        DirectionButton(
          icon: Icons.arrow_drop_down,
          onAction: isConnected
              ? () => _sendCommand(ref, KeyCodes.dpadDown.adbCommand)
              : null,
        ),
      ],
    );
  }

  Row homeControl(bool isConnected, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ATRÁS (Keyevent 4)
        DirectionButton(
          icon: Icons.arrow_back,
          onAction: isConnected
              ? () => _sendCommand(ref, KeyCodes.back.adbCommand)
              : null,
        ),
        const SizedBox(width: 40),
        // HOME (Keyevent 3)
        DirectionButton(
          icon: Icons.home,
          color: Colors.grey.shade200,
          onAction: isConnected
              ? () => _sendCommand(ref, KeyCodes.home.adbCommand)
              : null,
        ),
      ],
    );
  }

  Row volumenControl(bool isConnected, WidgetRef ref) {
    // FILA DE VOLUMEN
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // BAJAR VOLUMEN (Keyevent 25)
        DirectionButton(
          icon: Icons.volume_down,
          onAction: isConnected
              ? () => _sendCommand(ref, 'media volume --adj lower')
              : null,
        ),
        const SizedBox(width: 40),
        // SUBIR VOLUMEN (Keyevent 24)
        DirectionButton(
          icon: Icons.volume_up,
          onAction: isConnected
              ? () => _sendCommand(ref, 'media volume --adj raise')
              : null,
        ),
      ],
    );
  }

  Widget otherControls(bool isConnected, WidgetRef ref) {
    return Row(
      children: [
        DirectionButton(
          icon: _speechToText.isListening ? Icons.graphic_eq : Icons.mic,
          color: _speechToText.isListening ? Colors.green : Colors.redAccent,
          onAction: isConnected ? () => _startListening(ref) : null,
        ),
        DirectionButton(
          icon: Icons.close,
          onAction: isConnected ? () => _cleanEverything(ref) : null,
        ),
      ],
    );
  }

  Widget appsControl(bool isConnected, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AndroidTVApps.values.map((app) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: _getAppIcon(app),
              onPressed: isConnected
                  ? () => _sendCommand(ref, app.launchCommand)
                  : null,
              tooltip: app.name.toUpperCase(),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Función auxiliar para asignar iconos (puedes personalizarlos)
  Widget _getAppIcon(AndroidTVApps app) {
    switch (app) {
      case AndroidTVApps.youtube:
        return const Icon(Icons.yard_outlined, color: Colors.red, size: 40);
      case AndroidTVApps.netflix:
        return const Icon(
          Icons.play_circle_outline_rounded,
          color: Colors.red,
          size: 40,
        );
      case AndroidTVApps.amazonPrime:
        return const Icon(Icons.movie, color: Colors.blue, size: 40);
      default:
        return const Icon(Icons.apps, size: 40);
    }
  }

  Future<void> _cleanEverything(WidgetRef ref) async {
    final connection = ref.read(adbConnectionProvider);
    if (connection == null) return;

    try {
      final stream = await connection.openShell();

      // 1. Comando potente: Obtiene lista de apps de usuario y les hace force-stop
      // Explicación: pm list saca las apps, cut limpia el texto y xargs ejecuta force-stop para cada una.
      await stream.writeString(
        'for pkg in \$(pm list packages -3 | cut -f 2 -d ":"); do am force-stop \$pkg; done\n',
      );

      // 2. Esperamos un instante a que el sistema procese los cierres
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. Volvemos al Home (esto relanza el Launcher oficial)
      await stream.writeString('input keyevent 3\n');

      stream.close();
    } catch (e) {
      debugPrint('Error en limpieza profunda: $e');
    }
  }
}
