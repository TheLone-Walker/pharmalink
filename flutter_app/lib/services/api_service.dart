import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'storage_service.dart';
import '../utils/constants.dart';
import '../main.dart';
import '../screens/auth/login_screen.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = AppStorageService();
  late final Dio _dio;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Try to refresh the token
          final refreshToken = await _storage.read(key: 'refresh_token');
          if (refreshToken != null) {
            try {
              final res = await Dio().post(
                '${AppConstants.baseUrl}/auth/refresh-token',
                data: {'refreshToken': refreshToken},
              );
              final newToken = res.data['data']['accessToken'];
              await _storage.write(key: 'access_token', value: newToken);
              // Retry original request with new token
              e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              final response = await _dio.fetch(e.requestOptions);
              return handler.resolve(response);
            } catch (_) {
              // Refresh token expired — only NOW logout the user
              await _storage.deleteAll();
              navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            }
          }
        }
        return handler.next(e);
      },
    ));
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data}) => _dio.post(path, data: data);
  Future<Response> put(String path, {dynamic data}) => _dio.put(path, data: data);
  Future<Response> patch(String path, {dynamic data}) => _dio.patch(path, data: data);
  Future<Response> delete(String path) => _dio.delete(path);
  Future<Response> postForm(String path, FormData data) => _dio.post(path, data: data);
}
