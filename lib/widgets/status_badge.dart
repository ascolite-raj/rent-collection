import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({super.key, required this.label, required this.color});

  factory StatusBadge.forStatus(String status) {
    switch (status) {
      case 'occupied':
      case 'active':
      case 'paid':
      case 'refunded':
        return StatusBadge(label: _titleCase(status), color: Colors.green);
      case 'vacant':
      case 'pending':
      case 'held':
        return StatusBadge(label: _titleCase(status), color: Colors.orange);
      case 'partial':
      case 'partially_refunded':
        return StatusBadge(label: _titleCase(status), color: Colors.blue);
      case 'inactive':
      case 'closed':
        return StatusBadge(label: _titleCase(status), color: Colors.grey);
      default:
        return StatusBadge(label: _titleCase(status), color: Colors.grey);
    }
  }

  static String _titleCase(String value) {
    return value
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
