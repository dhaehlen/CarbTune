import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/pressure_unit.dart';
import '../models/sensor_data.dart';

enum ConnectionStatus { disconnected, searching, connected }

class AppState extends ChangeNotifier {
  /// Gauge display range in cmHg vacuum.
  static const double gaugeMin = 0.0;
  static const double gaugeMax = 30.0;

  static const int sensorCount = 4;

  /// Default target vacuum: mid-point of the CB400F balanced idle range (16–24 cmHg).
  static const double defaultTargetCmHg = 20.0;

  /// Default averaging window in seconds (LD-12).
  /// Mimics the damping effect of a traditional plenum/damper valve.
  static const double defaultAveragingWindowSec = 5.0;

  ConnectionStatus _status = ConnectionStatus.disconnected;

  /// Always length == sensorCount. Values are rolling averages, not raw readings.
  List<SensorData> _sensors = List.generate(
    sensorCount,
    (i) => SensorData(id: i, vacuumCmHg: 0),
  );

  PressureUnit _unit = PressureUnit.cmHg;
  double _targetCmHg = defaultTargetCmHg;
  double _rpm = 0.0;

  /// Rolling averaging window length in seconds (LD-12). Adjustable at runtime.
  double _averagingWindowSec = defaultAveragingWindowSec;

  /// Per-sensor ring buffer: list of (timestamp_ms, raw_pressure_cmHg).
  /// Used to compute the rolling average displayed on the gauges.
  final List<List<(int, double)>> _rawBuffers =
      List.generate(sensorCount, (_) => []);

  // ── Mock data ──────────────────────────────────────────────────────────────
  // Slightly unbalanced base vacuum values to simulate real-world tuning.
  // TODO: replace _startMockStream with BLE data stream (MA-01a / WC-01).
  final _baseValues = [14.0, 16.5, 13.0, 15.5];
  final _rng = Random();
  Timer? _mockTimer;

  // ── Getters ────────────────────────────────────────────────────────────────
  ConnectionStatus get connectionStatus => _status;
  List<SensorData> get sensors => _sensors;
  PressureUnit get unit => _unit;
  double get targetCmHg => _targetCmHg;
  double get rpm => _rpm;
  double get averagingWindowSec => _averagingWindowSec;

  AppState() {
    _simulateConnection();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void setUnit(PressureUnit unit) {
    _unit = unit;
    notifyListeners();
  }

  /// Called when the user drags the target pressure line on the gauge.
  void setTarget(double cmHg) {
    _targetCmHg = cmHg.clamp(gaugeMin, gaugeMax);
    notifyListeners();
  }

  /// Adjusts the rolling average window at runtime (LD-12).
  /// Range: 0.5 – 30 s.
  void setAveragingWindow(double seconds) {
    _averagingWindowSec = seconds.clamp(0.5, 30.0);
    notifyListeners();
  }

  // ── Rolling average helpers ────────────────────────────────────────────────

  void _recordRaw(int sensorId, double pressureCmHg) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final buf = _rawBuffers[sensorId];
    buf.add((now, pressureCmHg));
    final cutoffMs = now - (_averagingWindowSec * 1000).round();
    buf.removeWhere((e) => e.$1 < cutoffMs);
  }

  double _averaged(int sensorId) {
    final buf = _rawBuffers[sensorId];
    if (buf.isEmpty) return 0;
    return buf.fold(0.0, (sum, e) => sum + e.$2) / buf.length;
  }

  // ── Mock BLE simulation ────────────────────────────────────────────────────

  void _simulateConnection() {
    _status = ConnectionStatus.searching;
    notifyListeners();

    Future.delayed(const Duration(seconds: 2), () {
      _status = ConnectionStatus.connected;
      _rpm = 2300;
      _startMockStream();
      notifyListeners();
    });
  }

  void _startMockStream() {
    _mockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      // Record a raw reading for each sensor and expose the rolling average.
      for (var i = 0; i < sensorCount; i++) {
        final noise = (_rng.nextDouble() - 0.5) * 1.2;
        final raw = (_baseValues[i] + noise).clamp(gaugeMin, gaugeMax);
        _recordRaw(i, raw);
      }
      _sensors = List.generate(sensorCount, (i) {
        return SensorData(id: i, vacuumCmHg: _averaged(i));
      });
      _rpm = 2300 + (_rng.nextDouble() - 0.5) * 150;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _mockTimer?.cancel();
    super.dispose();
  }
}
