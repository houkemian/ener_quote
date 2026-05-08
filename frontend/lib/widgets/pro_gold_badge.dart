import 'package:flutter/material.dart';

/// Gold pill badge for PRO-only features (aligned with Settings section headers).
class ProGoldBadge extends StatelessWidget {
  const ProGoldBadge({super.key, this.label = '[PRO]'});

  final String label;

  static const Color _gold = Color(0xFFFFD66B);
  static const Color _text = Color(0xFF5B3A00);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _gold,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _text,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
