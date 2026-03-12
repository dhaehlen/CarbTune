/// Pressure display units supported by the app (LD-02, HI-03).
/// All internal pressure values are stored as kPa absolute.
/// Display conversions in [fromKPa] express all units as vacuum below
/// standard atmospheric (101.325 kPa), consistent with the FSD unit
/// conversion table in Section 6.5.
enum PressureUnit { cmHg, inHg, kPa, mbar, psi }

extension PressureUnitExtension on PressureUnit {
  String get label => switch (this) {
        PressureUnit.cmHg => 'cmHg',
        PressureUnit.inHg => 'inHg',
        PressureUnit.kPa => 'kPa',
        PressureUnit.mbar => 'mbar',
        PressureUnit.psi => 'PSI',
      };

  /// Convert an absolute pressure value from kPa to this display unit.
  /// All units are expressed as vacuum below standard atmospheric (101.325 kPa).
  double fromKPa(double kPa) {
    const atm = 101.325; // standard atmospheric pressure in kPa
    final vacuum = atm - kPa;
    return switch (this) {
      PressureUnit.cmHg => vacuum / 0.133322,
      PressureUnit.inHg => vacuum / 0.338639, // = 2.54 × 0.133322 kPa/inHg
      PressureUnit.kPa => vacuum,
      PressureUnit.mbar => vacuum * 10.0,
      PressureUnit.psi => vacuum * 0.145038,
    };
  }

  int get decimalPlaces => switch (this) {
        PressureUnit.cmHg => 1,
        PressureUnit.inHg => 2,
        PressureUnit.kPa => 2,
        PressureUnit.mbar => 1,
        PressureUnit.psi => 3,
      };

  String format(double kPa) => fromKPa(kPa).toStringAsFixed(decimalPlaces);
}
