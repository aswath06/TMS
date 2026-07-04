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
    final String type =
        vehicle['vehicle_type_name'] ?? vehicle['vehicle_type'] ?? "Vehicle";
    final String plate = vehicle['vehicle_number'] ?? "N/A";
    final String status = (vehicle['status'] ?? "IDLE")
        .toString()
        .toUpperCase();
    final String fuelType = vehicle['fuel_type'] ?? "N/A";
    final String odometer = vehicle['current_odometer']?.toString() ?? "0";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                        style: TextStyle(
                          color: subColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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
                      Icon(
                        Icons.person_rounded,
                        size: 12,
                        color: subColor.withValues(alpha: 0.5),
                      ),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: _buildInfoBadge(
                        Icons.local_gas_station_rounded,
                        fuelType,
                        subColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: _buildInfoBadge(
                        Icons.speed_rounded,
                        "$odometer km",
                        subColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [_buildStatusBadge(status)],
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

  Widget _buildInfoBadge(IconData icon, String text, Color subColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: subColor.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: subColor.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final Map<String, Map<String, Color>> statusStyles = {
      'ACTIVE': {
        'bg': const Color(0xFFECFDF5),
        'text': const Color(0xFF10B981),
        'border': const Color(0xFFA7F3D0),
      },
      'AVAILABLE': {
        'bg': const Color(0xFFECFDF5),
        'text': const Color(0xFF10B981),
        'border': const Color(0xFFA7F3D0),
      },
      'ON_TRIP': {
        'bg': const Color(0xFFEEF2FF),
        'text': const Color(0xFF6366F1),
        'border': const Color(0xFFC7D2FE),
      },
      'MAINTENANCE': {
        'bg': const Color(0xFFFFFBEB),
        'text': const Color(0xFFF59E0B),
        'border': const Color(0xFFFDE68A),
      },
      'REPAIR': {
        'bg': const Color(0xFFFEF2F2),
        'text': Colors.red,
        'border': const Color(0xFFFECACA),
      },
    };

    final style =
        statusStyles[status] ??
        {
          'bg': Colors.grey.withValues(alpha: 0.1),
          'text': Colors.grey,
          'border': Colors.grey.withValues(alpha: 0.2),
        };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style['bg'],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style['border']!, width: 1),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: style['text'],
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
