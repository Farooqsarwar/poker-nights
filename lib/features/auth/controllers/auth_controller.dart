import 'package:get/get.dart';
import 'package:poker_night/features/auth/models/user_model.dart';
import 'package:poker_night/services/auth_service.dart';

class AuthController extends GetxController {
  final AuthService _authService;

  AuthController(this._authService);

  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);
  final RxBool isLoading = false.obs;
  final RxString error = ''.obs;

  Future<void> login(String email, String password) async {
    isLoading.value = true;
    error.value = '';
    try {
      final user = await _authService.login(email, password);
      currentUser.value = user;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register(String name, String email, String password) async {
    isLoading.value = true;
    error.value = '';
    try {
      final user = await _authService.register(name, email, password);
      currentUser.value = user;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    currentUser.value = null;
  }

  Future<void> checkAuth() async {
    final user = await _authService.checkAuth();
    currentUser.value = user;
  }

  Future<void> updateProfile(String name, String? avatarUrl) async {
    await _authService.updateProfile(name, avatarUrl);
    final user = await _authService.checkAuth();
    currentUser.value = user;
  }

  Future<void> sendPasswordReset(String email) async {
    await _authService.sendPasswordReset(email);
  }

  bool get isAuthenticated => currentUser.value != null;
}
