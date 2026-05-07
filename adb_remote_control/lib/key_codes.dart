enum KeyCodes {
  unknown(0),
  softLeft(1),
  softRight(2),
  home(3),
  back(4),
  call(5),
  endcall(6),
  n0(7), n1(8), n2(9), n3(10), n4(11), n5(12), n6(13), n7(14), n8(15), n9(16),
  star(17),
  pound(18),
  dpadUp(19),
  dpadDown(20),
  dpadLeft(21),
  dpadRight(22),
  dpadCenter(23),
  volumeUp(24),
  volumeDown(25),
  power(26),
  enter(66),
  del(67),
  menu(82),
  search(84),
  appSwitch(187),
  mute(164);
  // ... puedes seguir añadiendo los que necesites de tu lista siguiendo este patrón

  final int value;
  const KeyCodes(this.value);

  // Método útil para generar el comando ADB
  String get adbCommand => 'input keyevent $value';
}

enum AndroidTVApps {
  youtube('com.google.android.youtube.tv/com.google.android.apps.youtube.tv.activity.ShellActivity'),
  netflix('com.netflix.ninja/.MainActivity'),
  amazonPrime('com.amazon.amazonvideo.livingroom/com.amazon.ignition.IgnitionActivity'),
  watchIt('com.watchit.vod/.refactor.splash.ui.SplashActivity'),
  shahid('net.mbc.shahidTV/.MainActivity');

  final String component;
  const AndroidTVApps(this.component);

  // Comando para abrir la app directamente
  String get launchCommand => 'am start -n $component';
}

/*
* ¿Cómo conseguir más nombres de aplicaciones?Si tienes una app instalada en el emulador y no sabes su ruta, ejecuta este comando en tu terminal de PC mientras la app está abierta:adb shell dumpsys window | grep -E 'mCurrentFocus'
* Eso te devolverá algo como: mCurrentFocus=Window{... com.android.settings/.Settings}, donde lo que está después del = es lo que debes poner en tu enum.¿Te gustaría que te ayude a crear un menú desplegable para no ocupar tanto espacio con los botones de apps?
* */