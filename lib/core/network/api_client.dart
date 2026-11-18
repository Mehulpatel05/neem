import 'dart:convert';

import 'package:http/http.dart' as http;

import '../storage/secure_storage.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool isAuthError;

  ApiException(this.message, {this.statusCode, this.isAuthError = false});

  @override
  String toString() {
    final code = statusCode == null ? '' : ' (statusCode: $statusCode)';
    return 'ApiException: $message$code';
  }
}

typedef _RefreshTokenHandler = Future<String?> Function();
typedef _LogoutHandler = void Function();

class ApiClient {
  ApiClient._internal();
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  static const String _baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://43.204.215.17');
  static const String _tokenKey = 'auth_token';

  static final http.Client _client = http.Client();

  static _RefreshTokenHandler? _refreshTokenHandler;
  static _LogoutHandler? _logoutHandler;

  static void setRefreshTokenHandler(_RefreshTokenHandler? handler) {
    _refreshTokenHandler = handler;
  }

  static void setLogoutHandler(_LogoutHandler? handler) {
    _logoutHandler = handler;
  }

  static Future<Map<String, String>> _headers({Map<String, String>? extra}) async {
    final token = await SecureStorage.read(_tokenKey);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    headers.addAll(extra ?? {});
    return headers;
  }

  static Future<dynamic> get(String path, {Map<String, String>? headers}) =>
      _request('GET', path, headers: headers);

  static Future<dynamic> post(String path,
      {Map<String, String>? headers, Object? body}) =>
      _request('POST', path, headers: headers, body: body);

  static Future<dynamic> put(String path,
      {Map<String, String>? headers, Object? body}) =>
      _request('PUT', path, headers: headers, body: body);

  static Future<dynamic> delete(String path, {Map<String, String>? headers}) =>
      _request('DELETE', path, headers: headers);

  static Future<dynamic> patch(String path,
      {Map<String, String>? headers, Object? body}) =>
      _request('PATCH', path, headers: headers, body: body);

  static Future<Map<String, dynamic>> uploadUserFile({
    required String folder,
    required String filename,
    required List<int> bytes,
    String contentType = 'application/octet-stream',
  }) async {
    final base64Data = base64Encode(bytes);
    final response = await post('/api/v1/storage/upload', body: {
      'folder': folder,
      'filename': filename,
      'contentType': contentType,
      'data': base64Data,
    });
    return response as Map<String, dynamic>;
  }

  static Future<List<dynamic>> listUserFiles([String? folder]) async {
    final query = folder != null ? '?folder=$folder' : '';
    final response = await get('/api/v1/storage/files$query');
    return (response['files'] as List<dynamic>?) ?? [];
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final response = await get('/api/v1/storage/user-data');
      return response['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveUserData(Map<String, dynamic> data) async {
    await post('/api/v1/storage/user-data', body: data);
  }

  static Future<void> deleteUserFile(String key) async {
    await post('/api/v1/storage/file', body: {'key': key});
  }

  static Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? headers,
    Object? body,
    bool retry = true,
  }) async {
    final url = Uri.parse('$_baseUrl$path');
    final requestHeaders = await _headers(extra: headers);
    final encodedBody = body == null ? null : jsonEncode(body);

    final response = await _send(method, url, requestHeaders, encodedBody);

    if (response.statusCode == 401) {
      if (retry) {
        final newToken = await _refreshToken();
        if (newToken != null) {
          await SecureStorage.write(_tokenKey, newToken);
          return _request(method, path, headers: headers, body: body, retry: false);
        }
      }
      await _logout();
      throw ApiException(
        'Authentication failed',
        statusCode: response.statusCode,
        isAuthError: true,
      );
    }

    return _handleResponse(response);
  }

  static Future<http.Response> _send(
    String method,
    Uri url,
    Map<String, String> headers,
    String? encodedBody,
  ) async {
    switch (method) {
      case 'GET':
        return await _client.get(url, headers: headers);
      case 'POST':
        return await _client.post(url, headers: headers, body: encodedBody);
      case 'PUT':
        return await _client.put(url, headers: headers, body: encodedBody);
      case 'DELETE':
        return await _client.delete(url, headers: headers, body: encodedBody);
      case 'PATCH':
        return await _client.patch(url, headers: headers, body: encodedBody);
      default:
        throw UnsupportedError('Unsupported HTTP method: $method');
    }
  }

  static Future<String?> _refreshToken() async {
    return _refreshTokenHandler?.call();
  }

  static Future<void> _logout() async {
    await SecureStorage.delete(_tokenKey);
    _logoutHandler?.call();
  }

  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    throw ApiException(
      _extractMessage(response),
      statusCode: response.statusCode,
      isAuthError: response.statusCode == 401,
    );
  }

  static String _extractMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['message']?.toString() ??
          decoded['error']?.toString() ??
          decoded['detail']?.toString() ??
          response.body;
    } catch (_) {
      return response.body.isEmpty
          ? 'Request failed with status ${response.statusCode}'
          : response.body;
    }
  }
}
