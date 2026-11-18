import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../telemetry/ethical_telemetry_service.dart';
import '../network/api_client.dart';

class AuthNotifier extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthNotifier() {
    _authService.addListener(_onAuthServiceChanged);
  }

  AuthState get authState => _authService.authState;
  String? get accessToken => _authService.accessToken;
  String? get refreshToken => _authService.refreshToken;
  Map<String, dynamic>? get currentUser => _authService.currentUser;
  String? get errorMessage => _authService.errorMessage;
  AuthService get authService => _authService;

  bool get isAuthenticated => authState == AuthState.authenticated;
  bool get isUnauthenticated => authState == AuthState.unauthenticated;
  bool get isAuthenticating => authState == AuthState.authenticating;
  bool get hasError => authState == AuthState.error;

  void _onAuthServiceChanged() {
    notifyListeners();
  }

  Future<String?> loginWithPhone(String phone) async {
    return await _authService.loginWithPhone(phone);
  }

  Future<bool> verifyOtp(String otp, [String? requestId]) async {
    return await _authService.verifyOtp(otp, requestId);
  }

  Future<void> refreshAccessToken() async {
    await _authService.refreshAccessToken();
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    return await _authService.getCurrentUser();
  }

  Future<void> logout() async {
    await _authService.logout();
  }
}

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  void setTheme(ThemeMode themeMode) {
    _themeMode = themeMode;
    notifyListeners();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }
}

class TelemetryNotifier extends ChangeNotifier {
  final EthicalTelemetryService _telemetryService;

  TelemetryNotifier()
      : _telemetryService = EthicalTelemetryService();

  void trackScreenView(String screenName) {
    _telemetryService.trackScreenView(screenName);
  }

  void trackInterest(String interestId) {
    _telemetryService.trackInterest(interestId);
  }

  void trackDwellTime(String screenName, Duration duration) {
    _telemetryService.trackDwellTime(screenName, duration);
  }

  void trackEvent(String eventType, Map<String, dynamic> data) {
    _telemetryService.trackEvent(eventType, data);
  }

  Future<void> flush() async {
    await _telemetryService.flush();
  }

  void startPeriodicFlush() {
    _telemetryService.startPeriodicFlush();
  }

  void stopPeriodicFlush() {
    _telemetryService.stopPeriodicFlush();
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    _telemetryService.handleAppLifecycleState(state);
  }

  @override
  void dispose() {
    _telemetryService.dispose();
    super.dispose();
  }
}

final authProvider = AuthNotifier();
final themeProvider = ThemeNotifier();
final telemetryProvider = TelemetryNotifier();


