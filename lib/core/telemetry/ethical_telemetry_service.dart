import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../network/api_client.dart';

class TelemetrySignal {
  final String screenName;
  final String eventType;
  final Map<String, dynamic> eventData;
  final DateTime timestamp;
  final int dwellTimeMs;

  TelemetrySignal({
    required this.screenName,
    required this.eventType,
    required this.eventData,
    required this.timestamp,
    this.dwellTimeMs = 0,
  });

  Map<String, dynamic> toJson() => {
        'screenName': screenName,
        'eventType': eventType,
        'eventData': eventData,
        'timestamp': timestamp.toIso8601String(),
        'dwellTimeMs': dwellTimeMs,
      };
}

class EthicalTelemetryService {
  static const int _maxQueueSize = 1000;
  static const Duration _flushInterval = Duration(minutes: 4);

  final List<TelemetrySignal> _queue = [];
  Timer? _flushTimer;
  final Map<String, DateTime> _screenStartTimes = <String, DateTime>{};
  final Map<String, int> _interestCounts = <String, int>{};

  EthicalTelemetryService();

  void trackScreenView(String screenName) {
    _enqueue(TelemetrySignal(
      screenName: screenName,
      eventType: 'screen_view',
      eventData: <String, dynamic>{},
      timestamp: DateTime.now(),
    ));
    _screenStartTimes[screenName] = DateTime.now();
  }

  void trackInterest(String interestId) {
    _interestCounts.update(interestId, (count) => count + 1, ifAbsent: () => 1);
    _enqueue(TelemetrySignal(
      screenName: '',
      eventType: 'interest',
      eventData: <String, dynamic>{'interestId': interestId},
      timestamp: DateTime.now(),
    ));
  }

  void trackDwellTime(String screenName, Duration duration) {
    _enqueue(TelemetrySignal(
      screenName: screenName,
      eventType: 'dwell_time',
      eventData: <String, dynamic>{},
      timestamp: DateTime.now(),
      dwellTimeMs: duration.inMilliseconds,
    ));
    _screenStartTimes.remove(screenName);
  }

  void trackEvent(String eventType, Map<String, dynamic> data) {
    _enqueue(TelemetrySignal(
      screenName: '',
      eventType: eventType,
      eventData: Map<String, dynamic>.from(data),
      timestamp: DateTime.now(),
    ));
  }

  void _enqueue(TelemetrySignal signal) {
    if (_queue.length >= _maxQueueSize) {
      _queue.removeAt(0);
    }
    _queue.add(signal);
  }

  Future<void> flush() async {
    if (_queue.isEmpty) return;

    final batch = List<Map<String, dynamic>>.from(
      _queue.map((signal) => signal.toJson()),
    );
    _queue.clear();

    try {
      await ApiClient.post(
        '/api/v1/telemetry/batch',
        body: jsonEncode(<String, dynamic>{'signals': batch}),
      );
    } catch (_) {
      _queue.addAll(
        batch.map((json) => TelemetrySignal(
          screenName: json['screenName'] as String,
          eventType: json['eventType'] as String,
          eventData: Map<String, dynamic>.from(json['eventData'] as Map),
          timestamp: DateTime.parse(json['timestamp'] as String),
          dwellTimeMs: json['dwellTimeMs'] as int? ?? 0,
        )),
      );
    }
  }

  void startPeriodicFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) => flush());
  }

  void stopPeriodicFlush() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _flushScreenDwellTimes();
      flush();
    } else if (state == AppLifecycleState.resumed) {
      startPeriodicFlush();
    }
  }

  void _flushScreenDwellTimes() {
    final now = DateTime.now();
    for (final entry in _screenStartTimes.entries) {
      trackDwellTime(entry.key, now.difference(entry.value));
    }
    _screenStartTimes.clear();
  }

  void dispose() {
    stopPeriodicFlush();
    _screenStartTimes.clear();
  }
}
