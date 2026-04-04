import 'package:flutter/material.dart';

class VehicleCard extends StatelessWidget {
  final dynamic vehicle;
  final Color cardColor;
  final Color titleColor;
  final Color subColor;

  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.cardColor,
    required this.titleColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    final String type = vehicle['vehicle_type_name'] ?? vehicle['vehicle_type'] ?? "Vehicle";
    final String plate = vehicle['vehicle_number'] ?? "N/A";
    final String status = (vehicle['status'] ?? "IDLE").toString().toUpperCase();
    
    // Status Color Map
    Color statusColor;
    switch (status) {
      case 'ACTIVE':
      case 'AVAILABLE':
        statusColor = Colors.green;
        break;
      case 'MAINTENANCE':
      case 'REPAIR':
        statusColor = Colors.orange;
        break;
      case 'ON_TRIP':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.red;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 65,
            width: 65,
            decoration: BoxDecoration(
              color: _getIconColor(type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(_getIcon(type), color: _getIconColor(type), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  plate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          type.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        "${vehicle['capacity'] ?? 0} Seats",
                        style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (vehicle['default_driver'] != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person_rounded, size: 12, color: subColor.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "Default: ${vehicle['default_driver']['name'] ?? 'N/A'}",
                          style: TextStyle(
                            fontSize: 11,
                            color: subColor.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                style: TextStyle(
                  fontSize: 9,
                  color: statusColor,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String type) {
    type = type.toLowerCase();
    if (type.contains('bus')) return Icons.directions_bus_rounded;
    if (type.contains('car')) return Icons.directions_car_rounded;
    if (type.contains('van')) return Icons.airport_shuttle_rounded;
    return Icons.local_shipping_rounded;
  }

  Color _getIconColor(String type) {
    type = type.toLowerCase();
    if (type.contains('bus')) return Colors.purple;
    if (type.contains('truck')) return Colors.orange;
    if (type.contains('van')) return Colors.blue;
    return Colors.indigo;
  }
}
