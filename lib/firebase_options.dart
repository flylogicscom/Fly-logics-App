// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('No hay configuración para Web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Plataforma no soportada.');
    }
  }

  // ANDROID  (coincide con google-services.json)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCFR7icd72Dq7M7Z1aHKEny-smLtOw-TQU',
    appId: '1:358305603983:android:51641701a83aa8153babfa',
    messagingSenderId: '358305603983',
    projectId: 'logbook-fly-logic',
    storageBucket: 'logbook-fly-logic.firebasestorage.app',
  );

  // iOS  (coincide con GoogleService-Info.plist)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBmf6sHcEBcUFQkjInGL39LYBoDao-nCbg',
    appId: '1:358305603983:ios:2063a92a807cb8b63babfa',
    messagingSenderId: '358305603983',
    projectId: 'logbook-fly-logic',
    storageBucket: 'logbook-fly-logic.firebasestorage.app',
    iosBundleId: 'com.flylogicdlogbookapp',
  );
}
