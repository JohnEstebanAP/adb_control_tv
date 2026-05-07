import 'dart:async';
import 'dart:convert';
import 'package:flutter_adb/adb_stream.dart'; // Asegúrate que el import sea el correcto de la librería

extension AdbStreamExtension on AdbStream {
  /// Lee la respuesta del stream y la convierte a String
  Future<String> readString({Duration timeout = const Duration(seconds: 3)}) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();

    // Escuchamos el stream de payloads de la clase original
    final subscription = onPayload.listen(
          (data) {
        buffer.write(utf8.decode(data));
      },
      onError: (error) => completer.completeError(error),
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(buffer.toString());
        }
      },
      cancelOnError: true,
    );

    // Timer de seguridad para no quedar esperando infinitamente
    Timer(timeout, () {
      if (!completer.isCompleted) {
        subscription.cancel();
        completer.complete(buffer.toString());
      }
    });

    return completer.future;
  }
}
