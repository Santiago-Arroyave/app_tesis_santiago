import 'package:flutter/material.dart';

class DiscardObservationDialog extends StatelessWidget {
  final VoidCallback onDiscard;
  final VoidCallback onContinue;

  const DiscardObservationDialog({
    super.key,
    required this.onDiscard,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_rounded, color: Colors.red.shade600, size: 56),
          const SizedBox(height: 12),
          const Text(
            '¿Quieres descartar la observación?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDiscard,
          child: Text('Descartar observación',
              style: TextStyle(color: Colors.red.shade600)),
        ),
        ElevatedButton(
          onPressed: onContinue,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white),
          child: const Text('Seguir editando'),
        ),
      ],
    );
  }
}