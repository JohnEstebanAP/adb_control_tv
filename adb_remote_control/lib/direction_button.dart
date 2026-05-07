import 'dart:async';
import 'package:flutter/material.dart';

class DirectionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onAction;
  final double size;
  final Color? color;

  const DirectionButton({
    super.key,
    required this.icon,
    this.onAction,
    this.size = 48,
    this.color,
  });

  @override
  State<DirectionButton> createState() => _DirectionButtonState();
}

class _DirectionButtonState extends State<DirectionButton> {
  Timer? _timer;
  Timer? _delayTimer;

  void _handlePressStart() {
    if (widget.onAction == null) return;

    // Ejecución inmediata real
    widget.onAction!();

    // Iniciar repetición tras 400ms
    _delayTimer = Timer(const Duration(milliseconds: 400), () {
      _timer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
        if (widget.onAction != null) widget.onAction!();
      });
    });
  }

  void _handlePressEnd() {
    _delayTimer?.cancel();
    _timer?.cancel();
  }

  @override
  void dispose() {
    _handlePressEnd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onAction != null;

    // 1. LISTENER: Captura el contacto físico ANTES que el botón
    return Listener(
      onPointerDown: (_) => _handlePressStart(),
      onPointerUp: (_) => _handlePressEnd(),
      onPointerCancel: (_) => _handlePressEnd(),
      child: IconButton(
        iconSize: widget.size,
        icon: Icon(widget.icon),
        // 2. IMPORTANTE: Dejamos onPressed vacío para el feedback visual,
        // pero el Listener de arriba ya envió el comando ADB.
        onPressed: isEnabled ? () {} : null,
        style: IconButton.styleFrom(
          backgroundColor: isEnabled
              ? (widget.color ?? Theme.of(context).colorScheme.primaryContainer)
              : Colors.grey.shade300,
          foregroundColor: isEnabled
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Colors.grey,
          shape: const CircleBorder(),
          padding: EdgeInsets.all(widget.size * 0.2),
          elevation: isEnabled ? 2 : 0,
        ),
      ),
    );
  }
}

