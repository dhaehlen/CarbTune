import 'package:flutter/material.dart';

import '../models/pressure_unit.dart';

/// Shows the "Change Units" modal dialog (LD-02).
/// Returns the newly selected [PressureUnit], or null if cancelled.
Future<PressureUnit?> showUnitSelector(
  BuildContext context,
  PressureUnit current,
) {
  return showDialog<PressureUnit>(
    context: context,
    builder: (_) => _UnitDialog(current: current),
  );
}

class _UnitDialog extends StatefulWidget {
  final PressureUnit current;
  const _UnitDialog({required this.current});

  @override
  State<_UnitDialog> createState() => _UnitDialogState();
}

class _UnitDialogState extends State<_UnitDialog> {
  late PressureUnit _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Units', textAlign: TextAlign.center),
      content: RadioGroup<PressureUnit>(
        groupValue: _selected,
        onChanged: (v) { if (v != null) setState(() => _selected = v); },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: PressureUnit.values.map((unit) {
            return RadioListTile<PressureUnit>(
              value: unit,
              title: Text(unit.label),
              activeColor: Colors.green,
            );
          }).toList(),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(_selected),
                child: const Text('Confirm'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
