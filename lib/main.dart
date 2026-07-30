import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'app.dart';
import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'services/voice_service.dart';
import 'features/auth/controllers/auth_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.initialize();
  
  // Inject Services and Controllers
  Get.put(StorageService.instance);
  Get.put(VoiceService.instance);
  Get.put<AuthService>(LocalAuthService(Get.find()));
  Get.put(AuthController(Get.find()));

  runApp(const PokerNightApp());
}
