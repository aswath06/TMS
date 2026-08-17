import 'package:flutter/material.dart';

class TaskThemeInfo {
  final IconData icon;
  final Color color;
  final Color bgTint;

  const TaskThemeInfo({
    required this.icon,
    required this.color,
    required this.bgTint,
  });
}

TaskThemeInfo getTaskThemeInfo(String title, String typeName, [String extraText = '']) {
  final combined = "${title.toLowerCase()} ${typeName.toLowerCase()} ${extraText.toLowerCase()}";

  if (combined.contains('emergenc') || combined.contains('sos') || combined.contains('urgent') || combined.contains('critical') || combined.contains('alert') || combined.contains('breakdown')) {
    return const TaskThemeInfo(
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFEF4444), // Vibrant Red
      bgTint: Color(0x1FEF4444),
    );
  }
  if (combined.contains('clean') || combined.contains('wash') || combined.contains('sanitiz')) {
    return const TaskThemeInfo(
      icon: Icons.cleaning_services_rounded,
      color: Color(0xFF0EA5E9), // Sky Blue
      bgTint: Color(0x1F0EA5E9),
    );
  }
  if (combined.contains('charge') || combined.contains('charging') || combined.contains('ev') || combined.contains('battery')) {
    return const TaskThemeInfo(
      icon: Icons.ev_station_rounded,
      color: Color(0xFF10B981), // Emerald Green
      bgTint: Color(0x1F10B981),
    );
  }
  if (combined.contains('fuel') || combined.contains('bunk') || combined.contains('petrol') || combined.contains('diesel') || combined.contains('gas')) {
    return const TaskThemeInfo(
      icon: Icons.local_gas_station_rounded,
      color: Color(0xFFF59E0B), // Amber Orange
      bgTint: Color(0x1FF59E0B),
    );
  }
  if (combined.contains('deliver') || combined.contains('cargo') || combined.contains('package') || combined.contains('goods') || combined.contains('outer') || combined.contains('courier')) {
    return const TaskThemeInfo(
      icon: Icons.local_shipping_rounded,
      color: Color(0xFF8B5CF6), // Purple
      bgTint: Color(0x1F8B5CF6),
    );
  }
  if (combined.contains('maint') || combined.contains('repair') || combined.contains('service') || combined.contains('fix') || combined.contains('mechanic') || combined.contains('engine')) {
    return const TaskThemeInfo(
      icon: Icons.build_circle_rounded,
      color: Color(0xFFEC4899), // Pink
      bgTint: Color(0x1FEC4899),
    );
  }
  if (combined.contains('inspect') || combined.contains('audit') || combined.contains('checkup') || combined.contains('verify')) {
    return const TaskThemeInfo(
      icon: Icons.fact_check_rounded,
      color: Color(0xFF14B8A6), // Teal
      bgTint: Color(0x1F14B8A6),
    );
  }
  if (combined.contains('tire') || combined.contains('tyre') || combined.contains('wheel') || combined.contains('punctur')) {
    return const TaskThemeInfo(
      icon: Icons.tire_repair_rounded,
      color: Color(0xFFF97316), // Orange
      bgTint: Color(0x1FF97316),
    );
  }
  if (combined.contains('oil') || combined.contains('lube') || combined.contains('lubricant') || combined.contains('fluid')) {
    return const TaskThemeInfo(
      icon: Icons.oil_barrel_rounded,
      color: Color(0xFFE65100), // Deep Orange
      bgTint: Color(0x1FE65100),
    );
  }
  if (combined.contains('shuttle') || combined.contains('campus') || combined.contains('run') || combined.contains('pickup') || combined.contains('drop') || combined.contains('bus') || combined.contains('route')) {
    return const TaskThemeInfo(
      icon: Icons.directions_bus_rounded,
      color: Color(0xFF6366F1), // Indigo
      bgTint: Color(0x1F6366F1),
    );
  }

  // Default fallback for general driver tasks
  return const TaskThemeInfo(
    icon: Icons.assignment_rounded,
    color: Color(0xFF6366F1), // Indigo
    bgTint: Color(0x1F6366F1),
  );
}

/// Dynamically returns the location or goal pin icon based on text content
IconData getLocationOrGoalIcon(String text, {bool isStart = true}) {
  final lower = text.toLowerCase().trim();

  if (lower.contains('bunk') || lower.contains('fuel') || lower.contains('petrol') || lower.contains('diesel')) {
    return Icons.local_gas_station_rounded;
  }
  if (lower.contains('charge') || lower.contains('charging') || lower.contains('ev') || lower.contains('battery')) {
    return Icons.ev_station_rounded;
  }
  if (lower.contains('campus') || lower.contains('block') || lower.contains('lobby') || lower.contains('hall') || lower.contains('office') || lower.contains('building')) {
    return Icons.business_rounded;
  }
  if (lower.contains('park') || lower.contains('depot') || lower.contains('garage') || lower.contains('stand') || lower.contains('yard')) {
    return Icons.local_parking_rounded;
  }
  if (lower.contains('clean') || lower.contains('wash')) {
    return Icons.cleaning_services_rounded;
  }
  if (lower.contains('maint') || lower.contains('repair') || lower.contains('service') || lower.contains('check')) {
    return Icons.build_circle_rounded;
  }
  if (lower.contains('deliver') || lower.contains('cargo') || lower.contains('package')) {
    return Icons.inventory_2_rounded;
  }
  if (lower.contains('square') || lower.contains('stop') || lower.contains('station') || lower.contains('road') || lower.contains('street') || lower.contains('gate')) {
    return Icons.place_rounded;
  }

  // Default fallback icons
  return isStart ? Icons.my_location_rounded : Icons.flag_rounded;
}

/// Computes the effective task status, evaluating if an ASSIGNED/PLANNED/STARTED task is OVERDUE based on scheduled start and duration.
String getEffectiveTaskStatus(Map<String, dynamic> task) {
  final String status = (task['status'] ?? 'ASSIGNED').toString().toUpperCase();
  if (status == 'COMPLETED' || status == 'VERIFIED' || status == 'CANCELLED') {
    return status;
  }

  // Explicit overdue flag from backend
  if (task['is_overdue'] == true || task['overdue'] == true || status == 'OVERDUE') {
    return 'OVERDUE';
  }

  // Check if scheduled end time is in the past
  final String startsAtStr = (task['starts_at'] ?? task['scheduled_start'] ?? '').toString();
  if (startsAtStr.isNotEmpty) {
    try {
      final DateTime startDateTime = DateTime.parse(startsAtStr).toLocal();
      final int durationMins = num.tryParse((task['duration_minutes'] ?? task['duration'] ?? 60).toString())?.toInt() ?? 60;
      final DateTime endDateTime = startDateTime.add(Duration(minutes: durationMins));

      if (DateTime.now().isAfter(endDateTime)) {
        return 'OVERDUE';
      }
    } catch (_) {}
  }

  return status;
}
