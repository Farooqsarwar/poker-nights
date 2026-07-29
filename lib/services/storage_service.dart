import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:localstore/localstore.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final _secure = const FlutterSecureStorage();
  final _local = Localstore.instance;

  Future<void> initialize() async {}

  Future<void> set(String key, dynamic value) async {
    if (value is String || value is int || value is double || value is bool) {
      await _secure.write(key: key, value: value.toString());
    } else if (value is List) {
      await _local.collection('app').doc(key).set({'data': value});
    } else {
      await _local.collection('app').doc(key).set(value as Map<String, dynamic>);
    }
  }

  T? get<T>(String key) {
    // Localstore is async, but for simplicity we use secure storage for primitives
    return null;
  }

  Future<String?> getString(String key) async {
    return await _secure.read(key: key);
  }

  Future<Map<String, dynamic>?> getJson(String key) async {
    final doc = await _local.collection('app').doc(key).get();
    return doc;
  }

  Future<void> remove(String key) async {
    await _secure.delete(key: key);
    await _local.collection('app').doc(key).delete();
  }

  Future<void> clear() async {
    await _secure.deleteAll();
    await _local.collection('app').delete();
  }
}

