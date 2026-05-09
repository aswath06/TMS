import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/store/faculty_store.dart';
import 'package:tripzo/store/VehicleStore.dart';
import '../../components/notification_bell.dart';

class SecurityDashboardScreen extends StatefulWidget {
  const SecurityDashboardScreen({super.key});

  @override
  State<SecurityDashboardScreen> createState() => _SecurityDashboardScreenState();
}

class _SecurityDashboardScreenState extends State<SecurityDashboardScreen> {
  @override
  void initState() {
    super.initState();
    if (useFacultyStore.profileData.value == null) {
      useFacultyStore.fetchProfile();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VehicleStore>().fetchVehicles(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryBlue.withValues(alpha: isDark ? 0.1 : 0.05),
              ),
            ),
          ),
          SafeArea(
            bottom: true,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  ValueListenableBuilder(
                    valueListenable: useFacultyStore.profileData,
                    builder: (context, data, _) {
                      return FutureBuilder<String?>(
                        future: UserStore.getName(),
                        builder: (context, snapshot) {
                          final String displayName =
                              data?['name'] ?? snapshot.data ?? "Security";
                          return _buildHeader(
                            displayName,
                            titleColor,
                            subColor,
                            screenWidth,
                            primaryBlue,
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 36),
                  _buildSectionTitle('Campus Vehicle Stats', titleColor),
                  const SizedBox(height: 18),
                  _buildStatsSection(primaryBlue, surfaceColor, isDark, screenWidth),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    String name,
    Color titleColor,
    Color subColor,
    double width,
    Color primary,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: FutureBuilder<String?>(
                  future: UserStore.getRole(),
                  builder: (context, snapshot) {
                    final String role = snapshot.data?.toUpperCase() ?? "SECURITY";
                    return Text(
                      'ROLE: $role',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hello, $name',
                style: TextStyle(
                  fontSize: width * 0.075,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                  letterSpacing: -1.2,
                ),
              ),
            ],
          ),
        ),
        NotificationBell(iconColor: titleColor),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [primary, primary.withValues(alpha: 0.4)],
            ),
          ),
          child: CircleAvatar(
            radius: width * 0.065,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: width * 0.06,
              backgroundImage: NetworkImage(
                'https://ui-avatars.com/api/?name=$name&background=6366F1&color=fff',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: -0.8,
      ),
    );
  }

  Widget _buildStatsSection(
    Color primaryBlue,
    Color surface,
    bool isDark,
    double width,
  ) {
    final vehicleStore = context.watch<VehicleStore>();
    
    if (vehicleStore.isLoading && vehicleStore.filteredVehicles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final int inCampus = vehicleStore.vehiclesInCampus;
    final int outCampus = vehicleStore.vehiclesOutCampus;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Inside Campus',
            value: inCampus.toString(),
            icon: Icons.local_parking_rounded,
            color: const Color(0xFF10B981), // Green
            surface: surface,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'Outside Campus',
            value: outCampus.toString(),
            icon: Icons.directions_car_rounded,
            color: const Color(0xFFF59E0B), // Orange
            surface: surface,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color surface,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 32,
              letterSpacing: -1.0,
              color: isDark ? Colors.white : Colors.black,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
