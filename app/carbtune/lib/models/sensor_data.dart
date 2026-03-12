/// One snapshot reading from a single carburetor pressure sensor.
/// [pressureKPa] is the absolute pressure in kPa, as received from the BLE
/// packet (HI-03). Convert to display units via PressureUnit.fromKPa().
class SensorData {
  final int id; // 0–3, matching carb cylinder number
  final double pressureKPa;
  final bool isActive;
  final bool isOutOfRange; // SA-05

  const SensorData({
    required this.id,
    required this.pressureKPa,
    this.isActive = true,
    this.isOutOfRange = false,
  });
}
