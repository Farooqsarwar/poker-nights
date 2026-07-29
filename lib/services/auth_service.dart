import 'package:poker_night/features/auth/models/user_model.dart';
import 'package:poker_night/services/storage_service.dart';

abstract class AuthService {
  Future<UserModel?> login(String email, String password);
  Future<UserModel?> register(String name, String email, String password);
  Future<void> logout();
  Future<UserModel?> checkAuth();
  Future<void> updateProfile(String name, String? avatarUrl);
  Future<void> sendPasswordReset(String email);
  Future<UserModel> createUser(String email, String name);
}

class LocalAuthService implements AuthService {
  final StorageService _storage;

  LocalAuthService(this._storage);

  @override
  Future<UserModel?> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final user = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: email.split('@').first,
      email: email,
      createdAt: DateTime.now(),
    );
    await _storage.set('current_user', user.toJson());
    return user;
  }

  @override
  Future<UserModel?> register(String name, String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final user = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      createdAt: DateTime.now(),
    );
    await _storage.set('current_user', user.toJson());
    return user;
  }

  @override
  Future<void> logout() async {
    await _storage.remove('current_user');
  }

  @override
  Future<UserModel?> checkAuth() async {
    final data = await _storage.getJson('current_user');
    if (data != null) {
      return UserModel.fromJson(data);
    }
    return null;
  }

  @override
  Future<void> updateProfile(String name, String? avatarUrl) async {
    final data = await _storage.getJson('current_user');
    if (data == null) return;
    final current = UserModel.fromJson(data);
    final updated = current.copyWith(name: name, avatarUrl: avatarUrl);
    await _storage.set('current_user', updated.toJson());
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<UserModel> createUser(String email, String name) async {
    final existing = await _storage.getJson('user_$email');
    if (existing != null) {
      return UserModel.fromJson(existing);
    }
    final user = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      createdAt: DateTime.now(),
    );
    await _storage.set('user_$email', user.toJson());
    return user;
  }
}

