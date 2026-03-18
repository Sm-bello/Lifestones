import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCOr0PGvWhb869qfKL-1PgbnE4iWpV4ivQ',
    appId: '1:125428172963:android:3e244ed67c2c6524989716',
    messagingSenderId: '125428172963',
    projectId: 'lifestones-9119b',
    storageBucket: 'lifestones-9119b.firebasestorage.app',
  );
}
