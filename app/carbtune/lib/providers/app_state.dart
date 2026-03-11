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

  ConnectionStatus _status = ConnectionStatus.disconnected;

  /// Always length == sensorCount. Zero-valued until connected.
  List<SensorData> _sensors = List.generate(
    sensorCount,
    (i) => SensorData(id: i, vacuumCmHg: 0),
  );

  PressureUnit _unit = PressureUnit.cmHg;
  double _targetCmHg = defaultTargetCmHg;
  double _rpm = 0.0;

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
      _sensors = List.generate(sensorCount, (i) {
        final noise = (_rng.nextDouble() - 0.5) * 1.2;
        final v = (_baseValues[i] + noise).clamp(gaugeMin, gaugeMax);
        return SensorData(id: i, vacuumCmHg: v);
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
