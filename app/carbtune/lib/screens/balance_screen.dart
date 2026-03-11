import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pressure_unit.dart';
import '../providers/app_state.dart';
import '../widgets/connection_status_bar.dart';
import '../widgets/unit_selector_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Root screen — adapts layout to orientation (LD-01, LD-05, TG-02, TG-03).
// ─────────────────────────────────────────────────────────────────────────────

class BalanceScreen extends StatelessWidget {
  const BalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            return orientation == Orientation.portrait
                ? const _PortraitLayout()
                : const _LandscapeLayout();
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Portrait layout
// ─────────────────────────────────────────────────────────────────────────────

class _PortraitLayout extends StatelessWidget {
  const _PortraitLayout();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConnectionStatusBar(status: state.connectionStatus),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'RPM: ${state.rpm.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _UnitButton(unit: state.unit),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: _PortraitGaugeArea(state: state)),
          const SizedBox(height: 8),
          _PortraitAvgRow(state: state),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Landscape layout
// ─────────────────────────────────────────────────────────────────────────────

class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: ConnectionStatusBar(status: state.connectionStatus)),
              const SizedBox(width: 12),
              Text(
                'RPM: ${state.rpm.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              _UnitButton(unit: state.unit),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avg label column — aligns with gauge bars via matching Expanded children.
                SizedBox(
                  width: 56,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Text(
                          'Avg',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                      ...List.generate(AppState.sensorCount, (i) {
                        final pressure = state.sensors[i].vacuumCmHg;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: _AvgLabel(pressure: pressure, unit: state.unit),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _LandscapeGaugeArea(state: state)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Portrait gauge area — 4 vertical bars + draggable horizontal target line.
// ─────────────────────────────────────────────────────────────────────────────

class _PortraitGaugeArea extends StatefulWidget {
  final AppState state;
  const _PortraitGaugeArea({required this.state});

  @override
  State<_PortraitGaugeArea> createState() => _PortraitGaugeAreaState();
}

class _PortraitGaugeAreaState extends State<_PortraitGaugeArea> {
  double _h = 1;

  double _pressureFromLocalY(double localY) {
    final frac = (1.0 - localY / _h).clamp(0.0, 1.0);
    return AppState.gaugeMin + frac * (AppState.gaugeMax - AppState.gaugeMin);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final targetFrac = _toFraction(state.targetCmHg);

    return LayoutBuilder(builder: (context, constraints) {
      _h = constraints.maxHeight;
      final targetY = (_h * (1 - targetFrac) - 1).clamp(0.0, _h - 2.0);

      return GestureDetector(
        onVerticalDragUpdate: (d) {
          context
              .read<AppState>()
              .setTarget(_pressureFromLocalY(d.localPosition.dy));
        },
        child: Stack(
          children: [
            // Graduated gridlines
            const Positioned.fill(
              child: CustomPaint(painter: _GridPainter(isPortrait: true)),
            ),
            // 4 vertical pressure bars
            Positioned.fill(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(AppState.sensorCount, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _PortraitBar(
                        pressure: state.sensors[i].vacuumCmHg,
                        target: state.targetCmHg,
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Draggable target line
            Positioned(
              left: 0,
              right: 0,
              top: targetY,
              height: 2,
              child: Container(color: Colors.red),
            ),
            // Drag handle dot
            Positioned(
              left: 4,
              top: targetY - 7,
              child: _DragHandle(),
            ),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Landscape gauge area — 4 horizontal bars + draggable vertical target line.
// ─────────────────────────────────────────────────────────────────────────────

class _LandscapeGaugeArea extends StatefulWidget {
  final AppState state;
  const _LandscapeGaugeArea({required this.state});

  @override
  State<_LandscapeGaugeArea> createState() => _LandscapeGaugeAreaState();
}

class _LandscapeGaugeAreaState extends State<_LandscapeGaugeArea> {
  double _w = 1;

  double _pressureFromLocalX(double localX) {
    final frac = (localX / _w).clamp(0.0, 1.0);
    return AppState.gaugeMin + frac * (AppState.gaugeMax - AppState.gaugeMin);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final targetFrac = _toFraction(state.targetCmHg);

    return LayoutBuilder(builder: (context, constraints) {
      _w = constraints.maxWidth;
      final targetX = (_w * targetFrac - 1).clamp(0.0, _w - 2.0);

      return GestureDetector(
        onHorizontalDragUpdate: (d) {
          context
              .read<AppState>()
              .setTarget(_pressureFromLocalX(d.localPosition.dx));
        },
        child: Stack(
          children: [
            // Graduated gridlines
            const Positioned.fill(
              child: CustomPaint(painter: _GridPainter(isPortrait: false)),
            ),
            // 4 horizontal pressure bars
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(AppState.sensorCount, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _LandscapeBar(
                        pressure: state.sensors[i].vacuumCmHg,
                        target: state.targetCmHg,
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Draggable target line
            Positioned(
              top: 0,
              bottom: 0,
              left: targetX,
              width: 2,
              child: Container(color: Colors.red),
            ),
            // Drag handle dot
            Positioned(
              left: targetX - 7,
              top: 4,
              child: _DragHandle(),
            ),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual bar widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PortraitBar extends StatelessWidget {
  final double pressure;
  final double target;

  const _PortraitBar({required this.pressure, required this.target});

  @override
  Widget build(BuildContext context) {
    final frac = _toFraction(pressure);
    final color = pressure >= target ? _colorOnTarget : _colorBelowTarget;

    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        alignment: Alignment.bottomCenter,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: double.infinity,
            height: constraints.maxHeight * frac,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            ),
          ),
        ],
      );
    });
  }
}

class _LandscapeBar extends StatelessWidget {
  final double pressure;
  final double target;

  const _LandscapeBar({required this.pressure, required this.target});

  @override
  Widget build(BuildContext context) {
    final frac = _toFraction(pressure);
    final color = pressure >= target ? _colorOnTarget : _colorBelowTarget;

    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        alignment: Alignment.centerLeft,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            height: double.infinity,
            width: constraints.maxWidth * frac,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
            ),
          ),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _UnitButton extends StatelessWidget {
  final PressureUnit unit;
  const _UnitButton({required this.unit});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.green.shade100,
        foregroundColor: Colors.green.shade800,
        side: BorderSide(color: Colors.green.shade700, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () async {
        final state = context.read<AppState>();
        final result = await showUnitSelector(context, state.unit);
        if (result != null) state.setUnit(result);
      },
      child: Text(unit.label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

/// Row of avg readout boxes below the portrait gauge bars.
class _PortraitAvgRow extends StatelessWidget {
  final AppState state;
  const _PortraitAvgRow({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 32,
          child: Text('Avg', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        ...List.generate(AppState.sensorCount, (i) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _AvgLabel(
                pressure: state.sensors[i].vacuumCmHg,
                unit: state.unit,
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Numeric pressure readout box used in avg rows/columns.
class _AvgLabel extends StatelessWidget {
  final double pressure;
  final PressureUnit unit;

  const _AvgLabel({required this.pressure, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        unit.format(pressure),
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red.shade200,
        border: Border.all(color: Colors.red, width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grid painter — draws scale lines across the gauge area.
// Lines at every 5 cmHg between gaugeMin and gaugeMax.
// ─────────────────────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final bool isPortrait;
  const _GridPainter({required this.isPortrait});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.8;

    const step = 5.0;
    var v = AppState.gaugeMin + step;
    while (v <= AppState.gaugeMax) {
      final frac = _toFraction(v);
      if (isPortrait) {
        final y = size.height * (1 - frac);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      } else {
        final x = size.width * frac;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      v += step;
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.isPortrait != isPortrait;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

const _colorOnTarget = Color(0xFF4CAF50); // green
const _colorBelowTarget = Color(0xFFFFC107); // amber

double _toFraction(double cmHg) =>
    ((cmHg - AppState.gaugeMin) / (AppState.gaugeMax - AppState.gaugeMin))
        .clamp(0.0, 1.0);
