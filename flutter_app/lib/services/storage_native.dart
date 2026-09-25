import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'storage_interface.dart';

class AppStorageService implements StorageService {
  static final AppStorageService _instance = AppStorageService._internal();
  factory AppStorageService() => _instance;
  AppStorageService._internal();

  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String? value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}
