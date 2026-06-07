import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tripzo/store/driver_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tripzo/store/providers.dart';
import 'package:tripzo/screens/admin/edit_driver_screen.dart';

class AdminDriverDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> driver;

  const AdminDriverDetailScreen({super.key, required this.driver});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color titleColor = isDark ? Colors.white : const Color(0xFF1E293B);

    final store = ref.read(driverStoreProvider);
    final status = driver['status'] ?? 1;
    final statusLabel = store.getStatusLabel(status);
    final statusColor = store.getStatusColor(status);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Driver Details",
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: primaryBlue),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditDriverScreen(driver: driver),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildProfileHero(
              context,
              isDark,
              surfaceColor,
              primaryBlue,
              statusLabel,
              statusColor,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Personal Information", titleColor),
                  const SizedBox(height: 16),
                  _buildInfoGrid(
                    [
                      _InfoItem(
                        Icons.person,
                        "Full Name",
                        driver['name'] ?? 'N/A',
                      ),
                      _InfoItem(Icons.phone, "Phone", driver['phone'] ?? 'N/A'),
                      _InfoItem(Icons.email, "Email", driver['email'] ?? 'N/A'),
                      _InfoItem(
                        Icons.bloodtype,
                        "Blood Group",
                        driver['driverProfile']?['blood_group'] ?? 'N/A',
                      ),
                      _InfoItem(
                        Icons.location_on,
                        "Address",
                        driver['driverProfile']?['address'] ?? 'N/A',
                      ),
                    ],
                    surfaceColor,
                    isDark,
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle("Professional Details", titleColor),
                  const SizedBox(height: 16),
                  _buildInfoGrid(
                    [
                      _InfoItem(
                        Icons.badge,
                        "Employee Code",
                        driver['driverProfile']?['employee_code'] ?? 'N/A',
                      ),
                      _InfoItem(
                        Icons.description,
                        "License No",
                        driver['driverProfile']?['license_number'] ?? 'N/A',
                      ),
                      _InfoItem(
                        Icons.event,
                        "License Expiry",
                        _formatDate(driver['driverProfile']?['license_expiry_date']),
                      ),
                      _InfoItem(
                        Icons.calendar_today,
                        "Joining Date",
                        _formatDate(driver['driverProfile']?['joining_date']),
                      ),
                      _InfoItem(
                        Icons.history,
                        "Experience",
                        "${driver['driverProfile']?['experience_years'] ?? 0} Years",
                      ),
                    ],
                    surfaceColor,
                    isDark,
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle("Emergency Contact", titleColor),
                  const SizedBox(height: 16),
                  _buildInfoGrid(
                    [
                      _InfoItem(
                        Icons.contact_emergency,
                        "Name",
                        driver['driverProfile']?['emergency_contact_name'] ?? 'N/A',
                      ),
                      _InfoItem(
                        Icons.phone_callback,
                        "Phone",
                        driver['driverProfile']?['emergency_contact_phone'] ?? 'N/A',
                      ),
                    ],
                    surfaceColor,
                    isDark,
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle("Statistics", titleColor),
                  const SizedBox(height: 16),
                  _buildStatsRow(primaryBlue, surfaceColor, isDark),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHero(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color primaryBlue,
    String statusLabel,
    Color statusColor,
  ) {
    final store = useDriverStore;
    final status = driver['status'] ?? 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [primaryBlue, primaryBlue.withOpacity(0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    _getInitials(driver['name'] ?? ''),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    store.getStatusIcon(status),
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            driver['name'] ?? 'Unknown',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "@${driver['user_name'] ?? 'username'}",
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(store.getStatusIcon(status), color: statusColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid(
    List<_InfoItem> items,
    Color surfaceColor,
    bool isDark,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(item.icon, size: 16, color: const Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.value,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(Color primaryBlue, Color surfaceColor, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "Total KM",
            "${driver['driverProfile']?['total_kilometer_drived'] ?? 0}",
            Icons.speed,
            primaryBlue,
            surfaceColor,
            isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            "Total Routes",
            "${driver['driverProfile']?['total_routes'] ?? 0}",
            Icons.route,
            const Color(0xFF10B981),
            surfaceColor,
            isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color surfaceColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "D";
    final parts = name.trim().split(RegExp(r'\s+'));
    String initials = parts.first[0];
    if (parts.length > 1) initials += parts.last[0];
    return initials.toUpperCase();
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr.toString());
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateStr.toString();
    }
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  _InfoItem(this.icon, this.label, this.value);
}
