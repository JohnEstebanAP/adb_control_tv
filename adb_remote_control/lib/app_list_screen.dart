import 'package:adb_remote_control/adb_stream_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main.dart';

class AppInfo {
  final String packageName;
  final String displayName;

  AppInfo({required this.packageName, required this.displayName});
}


final installedAppsProvider = FutureProvider<List<AppInfo>>((ref) async {
  final connection = ref.read(adbConnectionProvider);
  if (connection == null) return [];

  final stream = await connection.openShell();
  await stream.writeString('pm list packages -3\n');
  final response = await stream.readString();
  print("Apps instaladas: $response");
  stream.close();

  // Diccionario de nombres conocidos
  final Map<String, String> knownApps = {
    'com.google.android.youtube.tv': 'YouTube',
    'com.netflix.ninja': 'Netflix',
    'com.amazon.amazonvideo.livingroom': 'Amazon Prime Video',
    'com.disney.disneyplus': 'Disney+',
    'com.hbo.hbonow': 'HBO Max',
    'net.mbc.shahidTV': 'Shahid',
    // Agrega más según necesites
  };

  return response
      .split('\n')
      .where((line) => line.startsWith('package:'))
      .map((line) {
    final pkg = line.replaceFirst('package:', '').trim();
    return AppInfo(
      packageName: pkg,
      displayName: knownApps[pkg] ?? pkg, // Si no lo conoce, usa el ID
    );
  }).toList();
});


class AppListScreen extends ConsumerWidget {
  const AppListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(installedAppsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Aplicaciones Instaladas')),
      body: appsAsync.when(
        data: (apps) => ListView.separated(
          itemCount: apps.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final app = apps[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blueGrey.shade100,
                child: const Icon(Icons.tv, color: Colors.blue),
              ),
              title: Text(
                  app.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold)
              ),
              subtitle: Text(app.packageName, style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.play_arrow),
              onTap: () {
                final command = 'monkey -p ${app.packageName} -c android.intent.category.LAUNCHER 1';
                ref.read(adbConnectionProvider)?.openShell().then((s) {
                  s.writeString('$command\n');
                  s.close();
                });
              },
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error al cargar apps')),
      ),
    );
  }
}
