// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'storage_interface.dart';

class AppStorageService implements StorageService {
  static final AppStorageService _instance = AppStorageService._internal();
  factory AppStorageService() => _instance;
  AppStorageService._internal();

  @override
  Future<String?> read({required String key}) async {
    return html.window.sessionStorage[key];
  }

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value != null) {
      html.window.sessionStorage[key] = value;
    } else {
      html.window.sessionStorage.remove(key);
    }
  }

  @override
  Future<void> delete({required String key}) async {
    html.window.sessionStorage.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    html.window.sessionStorage.clear();
  }
}
