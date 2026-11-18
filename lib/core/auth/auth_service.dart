import 'package:flutter/material.dart';
import '../storage/secure_storage.dart';
import '../network/api_client.dart';

enum AuthState { unauthenticated, authenticating, authenticated, error }

class AuthService extends ChangeNotifier {
  AuthState _authState = AuthState.unauthenticated;
  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _currentUser;
  String? _errorMessage;
  String? _pendingRequestId;

  AuthState get authState => _authState;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  String? get pendingRequestId => _pendingRequestId;

  Future<String?> loginWithPhone(String phone) async {
    _setState(AuthState.authenticating);
    try {
      final response = await ApiClient.post('/api/v1/auth/request-otp', body: {
        'phoneNumber': phone,
        'phone': phone,
      });
      _pendingRequestId = response['requestId'] as String?;
      _errorMessage = null;
      _setState(AuthState.unauthenticated);
      return _pendingRequestId;
    } catch (e) {
      _errorMessage = e.toString();
      _setState(AuthState.error);
      return null;
    }
  }

  Future<bool> verifyOtp(String otp, [String? requestId]) async {
    _setState(AuthState.authenticating);
    final reqId = requestId ?? _pendingRequestId;
    if (reqId == null || reqId.isEmpty) {
      _errorMessage = 'No pending OTP request found. Please request OTP first.';
      _setState(AuthState.error);
      return false;
    }
    try {
      final response = await ApiClient.post('/api/v1/auth/verify-otp', body: {
        'requestId': reqId,
        'otp': otp,
      });

      _accessToken = response['accessToken'] as String?;
      _refreshToken = response['refreshToken'] as String?;

      if (_accessToken != null) {
        await SecureStorage.write('accessToken', _accessToken!);
      }
      if (_refreshToken != null) {
        await SecureStorage.write('refreshToken', _refreshToken!);
      }

      await getCurrentUser();
      _setState(AuthState.authenticated);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setState(AuthState.error);
      return false;
    }
  }

  Future<void> refreshAccessToken() async {
    _setState(AuthState.authenticating);
    try {
      final refresh = _refreshToken ?? await SecureStorage.read('refreshToken');
      if (refresh == null) throw Exception('No refresh token available');

      final response = await ApiClient.post('/api/v1/auth/refresh', body: {
        'refreshToken': refresh,
      });

      _accessToken = response['accessToken'] as String?;
      if (_accessToken != null) {
        await SecureStorage.write('accessToken', _accessToken!);
      }

      _errorMessage = null;
      _setState(AuthState.authenticated);
    } catch (e) {
      _errorMessage = e.toString();
      _setState(AuthState.error);
    }
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final response = await ApiClient.get('/api/v1/auth/me');
      _currentUser = response as Map<String, dynamic>?;
      notifyListeners();
      return _currentUser;
    } catch (e) {
      _errorMessage = e.toString();
      _currentUser = null;
      notifyListeners();
      return null;
    }
  }

  Future<void> saveInterests(List<String> interests) async {
    try {
      final response = await ApiClient.post(
        '/api/v1/users/me/interests',
        body: {'interests': interests},
      );
      _currentUser = response as Map<String, dynamic>?;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await ApiClient.post('/api/v1/auth/logout', body: {});
    } catch (_) {
      // Ignore logout errors; always clear local state
    }

    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    _errorMessage = null;
    await SecureStorage.delete('accessToken');
    await SecureStorage.delete('refreshToken');
    _setState(AuthState.unauthenticated);
  }

  void _setState(AuthState state) {
    _authState = state;
    notifyListeners();
  }
}
