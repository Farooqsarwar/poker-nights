import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    // Request permission (needed for iOS/Web)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    } else {
      debugPrint('User declined or has not accepted permission');
    }

    // Save token
    await _saveToken();

    // Listen for token updates
    _fcm.onTokenRefresh.listen((token) {
      _saveTokenToFirestore(token);
    });
  }

  Future<void> _saveToken() async {
    String? token;
    try {
      token = await _fcm.getToken();
    } catch (e) {
      debugPrint("FCM getToken failed: $e");
    }

    if (token != null) {
      await _saveTokenToFirestore(token);
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([token])
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Saving FCM token failed: $e");
    }
  }
}
