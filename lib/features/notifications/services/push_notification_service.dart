import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'dart:async';

import '../../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  String? _fcmToken;
  Future<String?>? _initialization;
  StreamSubscription<String>? _tokenRefreshSubscription;

  String? get fcmToken => _fcmToken;

  Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  Future<String?> initialize() => _initialization ??= _initialize();

  Future<String?> _initialize() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } on FirebaseException {
      // Notification display permission is not required to obtain an FCM token.
    }

    try {
      _fcmToken = await messaging.getToken();
    } on FirebaseException {
      _fcmToken = null;
    }
    _tokenRefreshSubscription ??= messaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
    });

    return _fcmToken;
  }

  Future<String?> getToken() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }
    return _fcmToken ?? await initialize();
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _initialization = null;
  }
}
