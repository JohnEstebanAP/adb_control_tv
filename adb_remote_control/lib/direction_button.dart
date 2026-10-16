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
        onPressed: isEnabled ? () {} : null,
        constraints: BoxConstraints.tightFor(
          width: widget.size + 28,
          height: widget.size + 28,
        ),
        style: IconButton.styleFrom(
          backgroundColor: isEnabled ? (widget.color ?? const Color(0xFF1D2942)) : const Color(0xFF171F32),
          foregroundColor: isEnabled ? Colors.white : Colors.white30,
          shape: const CircleBorder(),
          padding: EdgeInsets.zero,
          elevation: isEnabled ? 3 : 0,
          shadowColor: Colors.black.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
