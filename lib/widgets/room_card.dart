import 'package:flutter/material.dart';

import '../models/room.dart';
import '../repositories/dashboard_repository.dart';
import '../utils/formatters.dart';
import 'status_badge.dart';

class RoomCard extends StatelessWidget {
  final RoomCardData data;
  final VoidCallback onViewDetails;
  final VoidCallback? onAllocate;

  const RoomCard({super.key, required this.data, required this.onViewDetails, this.onAllocate});

  @override
  Widget build(BuildContext context) {
    final room = data.room;
    final isVacant = room.status == RoomStatus.vacant;

    return Card(
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Room ${room.roomNumber}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  StatusBadge.forStatus(room.status),
                ],
              ),
              const SizedBox(height: 10),
              if (isVacant)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(
                    onPressed: onAllocate,
                    child: const Text('Allocate Tenant'),
                  ),
                )
              else ...[
                _row('Tenant', data.tenantName ?? '-'),
                _row('Members', '${data.familyMembers}'),
                _row('Monthly Rent', formatCurrency(data.monthlyRent)),
                _row('Electricity', formatCurrency(data.currentMonthElectricity)),
                _row('Pending', formatCurrency(data.pending), valueColor: data.pending > 0 ? Colors.red : Colors.green),
                _row('Current Meter', data.currentMeterReading.toStringAsFixed(0)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: onViewDetails, child: const Text('View Details')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }
}
