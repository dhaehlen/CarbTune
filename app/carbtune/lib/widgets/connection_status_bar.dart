import 'package:flutter/material.dart';

import '../providers/app_state.dart';

/// Full-width status pill showing BLE connection state (MA-03).
class ConnectionStatusBar extends StatelessWidget {
  final ConnectionStatus status;

  const ConnectionStatusBar({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      ConnectionStatus.connected => ('Status: Connected', Colors.green),
      ConnectionStatus.searching => ('Status: Searching\u2026', Colors.orange),
      ConnectionStatus.disconnected => ('Status: Disconnected', Colors.red),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
