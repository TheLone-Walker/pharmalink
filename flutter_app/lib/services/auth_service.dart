import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'api_service.dart';

import 'socket_service.dart';

class AuthService extends ChangeNotifier {
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();

  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _lastError;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  String? get role => _user?['role'];
  bool get isLoggedIn => _user != null;

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void _setError(String? e) { _lastError = e; notifyListeners(); }

  void _initSocketConnection(Map<String, dynamic>? userData) {
    if (userData != null && userData['id'] != null) {
      final userId = userData['id'].toString();
      final role = userData['role']?.toString();
      final pharmacyId = userData['pharmacistProfile']?['id']?.toString();
      SocketService().connect(userId, role: role, pharmacyId: pharmacyId);
    }
  }

  Future<bool> login(String identifier, String password) async {
    _setLoading(true); _setError(null);
    try {
      final res = await _api.post('/auth/login', data: {'identifier': identifier, 'password': password});
      final data = res.data['data'];
      await _storage.write(key: 'access_token', value: data['accessToken']);
      await _storage.write(key: 'refresh_token', value: data['refreshToken']);
      await _storage.write(key: 'user', value: jsonEncode(data['user']));
      _user = data['user'];
      _initSocketConnection(_user);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_parseError(e));
      return false;
    } finally { _setLoading(false); }
  }

  Future<bool> register(Map<String, dynamic> data) async {
    _setLoading(true); _setError(null);
    try {
      final res = await _api.post('/auth/register', data: data);
      final d = res.data['data'];
      await _storage.write(key: 'access_token', value: d['accessToken']);
      await _storage.write(key: 'refresh_token', value: d['refreshToken']);
      await _storage.write(key: 'user', value: jsonEncode(d['user']));
      _user = d['user'];
      _initSocketConnection(_user);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_parseError(e));
      return false;
    } finally { _setLoading(false); }
  }

  Future<void> logout() async {
    SocketService().disconnect();
    await _storage.deleteAll();
    _user = null;
    notifyListeners();
  }

  Future<void> loadUser() async {
    final userStr = await _storage.read(key: 'user');
    if (userStr != null) {
      _user = jsonDecode(userStr);
      _initSocketConnection(_user);
      notifyListeners();
    }
  }

  Future<void> refreshUser() async {
    try {
      final res = await _api.get('/users/me');
      final userData = res.data['data'];
      if (userData != null) {
        _user = Map<String, dynamic>.from(userData);
        await _storage.write(key: 'user', value: jsonEncode(userData));
        notifyListeners();
      }
    } catch (_) {
      // fail silently — do not logout the user
    }
  }

  Future<bool> sendOtp(String phone) async {
    try {
      await _api.post('/auth/send-otp', data: {'phone': phone});
      return true;
    } catch (e) { _setError(_parseError(e)); return false; }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    try {
      await _api.post('/auth/verify-otp', data: {'phone': phone, 'otp': otp});
      return true;
    } catch (e) { _setError(_parseError(e)); return false; }
  }

  String _parseError(dynamic e) {
    if (e is DioException) {
      final resData = e.response?.data;
      if (resData is Map && resData['message'] != null) {
        return resData['message'].toString();
      }
      if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        return 'Unable to connect to server. Ensure backend is running.';
      }
      if (e.message != null && e.message!.isNotEmpty) {
        return e.message!;
      }
    }
    final str = e.toString();
    if (str.contains('Exception:')) {
      return str.replaceAll('Exception:', '').trim();
    }
    return 'Something went wrong. Please check your connection.';
  }
}
