import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/pressure_unit.dart';
import '../models/sensor_data.dart';

enum ConnectionStatus { disconnected, searching, connected }

class AppState extends ChangeNotifier {
  /// Gauge display range in kPa absolute (spans 0–30 cmHg vacuum relative to 101.325 kPa atm).
  static const double gaugeMinKPa = 97.325; // ≈ 30 cmHg vacuum
  static const double gaugeMaxKPa = 101.325; // ≈ 0 cmHg vacuum (standard atmospheric)

  static const int sensorCount = 4;

  /// Default target: mid-point of the CB400F balanced idle range (16–24 cmHg ≈ 99.5–98.2 kPa).
  static const double defaultTargetKPa = 98.659; // ≈ 20 cmHg vacuum

  /// Default averaging window in seconds (LD-12).
  /// Mimics the damping effect of a traditional plenum/damper valve.
  static const double defaultAveragingWindowSec = 5.0;

  ConnectionStatus _status = ConnectionStatus.disconnected;

  /// Always length == sensorCount. Values are rolling averages, not raw readings.
  List<SensorData> _sensors = List.generate(
    sensorCount,
    (i) => SensorData(id: i, pressureKPa: gaugeMaxKPa),
  );

  PressureUnit _unit = PressureUnit.cmHg;
  double _targetKPa = defaultTargetKPa;
  double _rpm = 0.0;

  /// Rolling averaging window length in seconds (LD-12). Adjustable at runtime.
  double _averagingWindowSec = defaultAveragingWindowSec;

  /// Per-sensor ring buffer: list of (timestamp_ms, raw_pressure_kPa).
  /// Used to compute the rolling average displayed on the gauges.
  final List<List<(int, double)>> _rawBuffers =
      List.generate(sensorCount, (_) => []);

  // ── Mock data ──────────────────────────────────────────────────────────────
  // Slightly unbalanced base pressures (kPa abs) to simulate real-world tuning.
  // Equivalent to [14.0, 16.5, 13.0, 15.5] cmHg vacuum.
  // TODO: replace _startMockStream with BLE data stream (MA-01a / WC-01).
  final _baseValues = [99.458, 99.125, 99.592, 99.258];
  final _rng = Random();
  Timer? _mockTimer;

  // ── Getters ────────────────────────────────────────────────────────────────
  ConnectionStatus get connectionStatus => _status;
  List<SensorData> get sensors => _sensors;
  PressureUnit get unit => _unit;
  double get targetKPa => _targetKPa;
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
  void setTarget(double kPa) {
    _targetKPa = kPa.clamp(gaugeMinKPa, gaugeMaxKPa);
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
        final noise = (_rng.nextDouble() - 0.5) * 0.160; // ≈ 1.2 cmHg in kPa
        final raw = (_baseValues[i] + noise).clamp(gaugeMinKPa, gaugeMaxKPa);
        _recordRaw(i, raw);
      }
      _sensors = List.generate(sensorCount, (i) {
        return SensorData(id: i, pressureKPa: _averaged(i));
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
