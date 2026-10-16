import 'package:adb_remote_control/adb_remote_control.dart';
import 'package:adb_remote_control/example_storage.dart';
import 'package:adb_remote_control/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_adb/flutter_adb.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptySavedDevices extends SavedDevicesNotifier {
  @override
  Future<List<SavedAdbDevice>> build() async => [];
}

void main() {
  testWidgets('App opens connection and pairing on a small screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adbCryptoProvider.overrideWith(
            (ref) => AdbCrypto(adbKeyName: 'test@control-tv'),
          ),
          savedDevicesProvider.overrideWith(_EmptySavedDevices.new),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CONTROL TV'), findsOneWidget);
    expect(find.text('Conectar'), findsOneWidget);
    expect(find.text('Dispositivos guardados'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final pairingButton = find.widgetWithText(
      OutlinedButton,
      'Emparejar con código',
    );
    await tester.ensureVisible(pairingButton);
    await tester.tap(pairingButton);
    await tester.pumpAndSettle();
    expect(find.text('Código de emparejamiento'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(640, 360));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(ElevatedButton, 'Emparejar'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Remote reflects speech status and disposes safely', (
    tester,
  ) async {
    const speechChannel = MethodChannel('plugin.csdcorp.com/speech_to_text');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(speechChannel, (call) async {
      switch (call.method) {
        case 'initialize':
          return true;
        case 'stop':
        case 'cancel':
          return null;
        default:
          throw StateError('Unexpected speech method: ${call.method}');
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(speechChannel, null));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AdbRemoteControl())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CONTROL REMOTO'), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

    Future<void> sendStatus(String status) async {
      await messenger.handlePlatformMessage(
        speechChannel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('notifyStatus', status),
        ),
        (_) {},
      );
      await tester.pump();
    }

    await sendStatus('listening');
    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    await sendStatus('notListening');
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await sendStatus('done');
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
