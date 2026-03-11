/// One snapshot reading from a single carburetor pressure sensor.
/// [vacuumCmHg] is the vacuum level (how far below atmospheric), in cmHg.
class SensorData {
  final int id; // 0–3, matching carb cylinder number
  final double vacuumCmHg;
  final bool isActive;
  final bool isOutOfRange; // SA-05

  const SensorData({
    required this.id,
    required this.vacuumCmHg,
    this.isActive = true,
    this.isOutOfRange = false,
  });
}
