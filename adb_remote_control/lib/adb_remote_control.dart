import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'app_list_screen.dart';
import 'direction_button.dart';
import 'key_codes.dart';
import 'main.dart';

const _background = Color(0xFF0B1020);
const _surface = Color(0xFF151D32);
const _surfaceRaised = Color(0xFF1D2942);
const _accent = Color(0xFF9B8CFF);
const _mint = Color(0xFF59E1C0);

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
    super.initState();
    unawaited(_initSpeech());
  }

  @override
  void dispose() {
    unawaited(_speechToText.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(adbConnectionProvider);
    final isConnected = connection != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 28,
            20,
            compact ? 16 : 28,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(isConnected, connection?.ip),
                  const SizedBox(height: 22),
                  _buildRemoteCard(isConnected, compact),
                  const SizedBox(height: 16),
                  _buildQuickControls(isConnected),
                  const SizedBox(height: 16),
                  _buildAppsCard(isConnected),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      'Toca para enviar · Mantén pulsado para repetir',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isConnected, String? ip) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_accent, Color(0xFF6C5CE7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.settings_remote_rounded, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONTROL REMOTO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isConnected
                    ? 'Listo para controlar tu TV'
                    : 'Conecta tu TV para comenzar',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (isConnected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _mint.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _mint.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: _mint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  ip ?? 'EN LÍNEA',
                  style: const TextStyle(
                    color: _mint,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRemoteCard(bool isConnected, bool compact) {
    return _GlassCard(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 28,
        vertical: 22,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.gamepad_rounded,
                size: 17,
                color: _accent.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              const Text(
                'NAVEGACIÓN',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.wifi_tethering_rounded,
                size: 16,
                color: _mint.withValues(alpha: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              DirectionButton(
                icon: Icons.keyboard_arrow_up_rounded,
                size: 30,
                color: _surfaceRaised,
                onAction: isConnected
                    ? () => _sendCommand(KeyCodes.dpadUp.adbCommand)
                    : null,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DirectionButton(
                    icon: Icons.keyboard_arrow_left_rounded,
                    size: 30,
                    color: _surfaceRaised,
                    onAction: isConnected
                        ? () => _sendCommand(KeyCodes.dpadLeft.adbCommand)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  _CenterButton(
                    enabled: isConnected,
                    onTap: isConnected
                        ? () => _sendCommand(KeyCodes.dpadCenter.adbCommand)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  DirectionButton(
                    icon: Icons.keyboard_arrow_right_rounded,
                    size: 30,
                    color: _surfaceRaised,
                    onAction: isConnected
                        ? () => _sendCommand(KeyCodes.dpadRight.adbCommand)
                        : null,
                  ),
                ],
              ),
              DirectionButton(
                icon: Icons.keyboard_arrow_down_rounded,
                size: 30,
                color: _surfaceRaised,
                onAction: isConnected
                    ? () => _sendCommand(KeyCodes.dpadDown.adbCommand)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _LabeledControl(
                icon: Icons.arrow_back_rounded,
                label: 'ATRÁS',
                enabled: isConnected,
                onTap: () => _sendCommand(KeyCodes.back.adbCommand),
              ),
              _LabeledControl(
                icon: Icons.home_rounded,
                label: 'INICIO',
                enabled: isConnected,
                highlighted: true,
                onTap: () => _sendCommand(KeyCodes.home.adbCommand),
              ),
              _LabeledControl(
                icon: Icons.menu_rounded,
                label: 'MENÚ',
                enabled: isConnected,
                onTap: () => _sendCommand(KeyCodes.menu.adbCommand),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickControls(bool isConnected) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickControlCard(
                icon: Icons.volume_down_rounded,
                label: 'VOLUMEN',
                value: 'BAJAR',
                onTap: isConnected
                    ? () => _sendCommand('media volume --adj lower')
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickControlCard(
                icon: Icons.volume_up_rounded,
                label: 'VOLUMEN',
                value: 'SUBIR',
                onTap: isConnected
                    ? () => _sendCommand('media volume --adj raise')
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickControlCard(
                icon: _speechToText.isListening
                    ? Icons.graphic_eq_rounded
                    : Icons.mic_rounded,
                label: 'BÚSQUEDA',
                value: 'VOZ',
                accent: _speechToText.isListening ? _mint : _accent,
                onTap: isConnected ? _startListening : null,
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: isConnected ? _cleanEverything : null,
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Cerrar apps abiertas'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white54,
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppsCard(bool isConnected) {
    return _GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.play_circle_outline_rounded,
                size: 18,
                color: _accent,
              ),
              const SizedBox(width: 8),
              const Text(
                'TUS APPS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AppListScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: _accent,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text(
                  'VER TODAS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: AndroidTVApps.values.map((app) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _AppShortcut(
                    name: _appName(app),
                    icon: _getAppIcon(app),
                    onTap: isConnected
                        ? () => _sendCommand(app.launchCommand)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _appName(AndroidTVApps app) {
    switch (app) {
      case AndroidTVApps.youtube:
        return 'YouTube';
      case AndroidTVApps.netflix:
        return 'Netflix';
      case AndroidTVApps.amazonPrime:
        return 'Prime';
      case AndroidTVApps.watchIt:
        return 'Watch It';
      case AndroidTVApps.shahid:
        return 'Shahid';
    }
  }

  Widget _getAppIcon(AndroidTVApps app) {
    switch (app) {
      case AndroidTVApps.youtube:
        return const Icon(
          Icons.smart_display_rounded,
          color: Color(0xFFFF5A67),
          size: 22,
        );
      case AndroidTVApps.netflix:
        return const Icon(
          Icons.movie_creation_outlined,
          color: Color(0xFFE50914),
          size: 22,
        );
      case AndroidTVApps.amazonPrime:
        return const Icon(
          Icons.local_movies_outlined,
          color: Color(0xFF65B9FF),
          size: 22,
        );
      default:
        return const Icon(
          Icons.ondemand_video_rounded,
          color: _accent,
          size: 22,
        );
    }
  }

  Future<void> _initSpeech() async {
    _isSpeechInitialized = await _speechToText.initialize(
      onStatus: (_) {
        if (mounted) setState(() {});
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _sendCommand(String command) async {
    final connection = ref.read(adbConnectionProvider);
    if (connection == null) return;

    try {
      final stream = await connection.openShell();
      await stream.writeString('$command\n');
      stream.close();
    } catch (e) {
      debugPrint('Error enviando comando ADB: $e');
    }
  }

  Future<void> _startListening() async {
    if (!_isSpeechInitialized) return;

    await _speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          unawaited(_sendVoiceSearch(result.recognizedWords));
        }
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _sendVoiceSearch(String query) async {
    final escapedQuery = query.replaceAll("'", "'\\''");
    await _sendCommand(
      "am start -a android.intent.action.SEARCH --es query '$escapedQuery'",
    );
  }

  Future<void> _cleanEverything() async {
    final connection = ref.read(adbConnectionProvider);
    if (connection == null) return;

    try {
      final stream = await connection.openShell();
      await stream.writeString(
        'for pkg in \$(pm list packages -3 | cut -f 2 -d ":"); do am force-stop \$pkg; done\n',
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await stream.writeString('input keyevent 3\n');
      stream.close();
    } catch (e) {
      debugPrint('Error cerrando las aplicaciones: $e');
    }
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({required this.enabled, this.onTap});

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = enabled
        ? const [_accent, Color(0xFF7160E8)]
        : const [Color(0xFF313B51), Color(0xFF242D42)];
    return SizedBox(
      width: 76,
      height: 76,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: enabled ? 0.3 : 0.08),
              blurRadius: 18,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const Center(
              child: Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledControl extends StatelessWidget {
  const _LabeledControl({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? _accent : Colors.white70;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: enabled ? color : Colors.white24, size: 22),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white54 : Colors.white24,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickControlCard extends StatelessWidget {
  const _QuickControlCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.accent = _accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: enabled ? accent : Colors.white24, size: 23),
              const SizedBox(height: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white30,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppShortcut extends StatelessWidget {
  const _AppShortcut({
    required this.name,
    required this.icon,
    required this.onTap,
  });

  final String name;
  final Widget icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _background.withValues(alpha: 0.56),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          constraints: const BoxConstraints(minWidth: 88),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              icon,
              const SizedBox(height: 6),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
