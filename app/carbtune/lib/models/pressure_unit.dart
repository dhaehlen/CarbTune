/// Pressure display units supported by the app (LD-02, SA-03).
/// All internal values are stored as vacuum in cmHg.
enum PressureUnit { cmHg, inHg, kPa, mbar, psi }

extension PressureUnitExtension on PressureUnit {
  String get label => switch (this) {
        PressureUnit.cmHg => 'cmHg',
        PressureUnit.inHg => 'inHg',
        PressureUnit.kPa => 'kPa',
        PressureUnit.mbar => 'mbar',
        PressureUnit.psi => 'PSI',
      };

  /// Convert a vacuum value from cmHg to this unit.
  double fromCmHg(double cmHg) => switch (this) {
        PressureUnit.cmHg => cmHg,
        PressureUnit.inHg => cmHg / 2.54,
        PressureUnit.kPa => cmHg * 0.133322,
        PressureUnit.mbar => cmHg * 1.33322,
        PressureUnit.psi => cmHg * 0.019337,
      };

  int get decimalPlaces => switch (this) {
        PressureUnit.cmHg => 1,
        PressureUnit.inHg => 2,
        PressureUnit.kPa => 2,
        PressureUnit.mbar => 1,
        PressureUnit.psi => 3,
      };

  String format(double cmHg) => fromCmHg(cmHg).toStringAsFixed(decimalPlaces);
}
