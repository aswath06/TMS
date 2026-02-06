import 'package:flutter/material.dart';

class MissionDetailsScreen extends StatefulWidget {
  final String missionTitle,
      time,
      driverName,
      driverPhone,
      vehicleInfo,
      capacity,
      pathType,
      status;
  final List<Map<String, String>> stops;
  final Color statusColor;

  const MissionDetailsScreen({
    super.key,
    required this.missionTitle,
    required this.time,
    required this.driverName,
    required this.driverPhone,
    required this.vehicleInfo,
    required this.capacity,
    required this.pathType,
    required this.stops,
    required this.status,
    required this.statusColor,
  });

  @override
  State<MissionDetailsScreen> createState() => _MissionDetailsScreenState();
}

class _MissionDetailsScreenState extends State<MissionDetailsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color subColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final Color primaryBlue = const Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildBackgroundDecor(isDark),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, titleColor),
                    const SizedBox(height: 30),
                    _buildHeroCard(cardColor, titleColor, subColor),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      "Live Tracking Preview",
                      primaryBlue,
                      titleColor,
                    ),
                    const SizedBox(height: 16),
                    _buildMapPlaceholder(primaryBlue),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      "Detailed Checkpoints",
                      primaryBlue,
                      titleColor,
                    ),
                    const SizedBox(height: 20),
                    _buildCheckpointList(primaryBlue, titleColor),
                    const SizedBox(height: 32),
                    _buildSectionTitle(
                      "Resource & Vehicle",
                      primaryBlue,
                      titleColor,
                    ),
                    const SizedBox(height: 16),
                    _buildDriverCard(cardColor, primaryBlue, subColor),
                    const SizedBox(height: 12),
                    _buildVehicleDetails(cardColor, primaryBlue, subColor),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color titleColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: titleColor,
            size: 22,
          ),
        ),
        Text(
          "Mission Details",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
        const SizedBox(width: 48), // Balancing for the back button
      ],
    );
  }

  Widget _buildHeroCard(Color cardColor, Color titleColor, Color subColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.status.toUpperCase(),
                  style: TextStyle(
                    color: widget.statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                "Start: ${widget.time}",
                style: TextStyle(color: subColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            widget.missionTitle,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.pathType,
            style: TextStyle(
              color: subColor,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color accent, Color titleColor) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: titleColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckpointList(Color blue, Color title) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.stops.length,
      itemBuilder: (context, index) {
        final stop = widget.stops[index];
        return _buildTimelineItem(
          location: stop['location']!,
          eta: stop['eta']!,
          isFirst: index == 0,
          isLast: index == widget.stops.length - 1,
          color: blue,
          titleColor: title,
        );
      },
    );
  }

  Widget _buildTimelineItem({
    required String location,
    required String eta,
    required bool isFirst,
    required bool isLast,
    required Color color,
    required Color titleColor,
  }) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFirst ? color : Colors.transparent,
                  border: Border.all(color: color, width: 3),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: color.withOpacity(0.2)),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    location,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  Text(
                    eta,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(Color cardColor, Color blue, Color sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: blue.withOpacity(0.1),
            child: Icon(Icons.person, color: blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.driverName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.driverPhone,
                  style: TextStyle(color: sub, fontSize: 12),
                ),
              ],
            ),
          ),
          CircleAvatar(
            backgroundColor: Colors.green.withOpacity(0.1),
            child: const Icon(Icons.call, size: 18, color: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleDetails(Color cardColor, Color blue, Color sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSmallInfo(
            Icons.directions_car,
            widget.vehicleInfo.split('(')[0],
            blue,
            sub,
          ),
          _buildSmallInfo(
            Icons.airline_seat_recline_normal,
            widget.capacity,
            blue,
            sub,
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInfo(IconData icon, String val, Color blue, Color sub) {
    return Row(
      children: [
        Icon(icon, size: 16, color: blue),
        const SizedBox(width: 8),
        Text(
          val,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildMapPlaceholder(Color primaryColor) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Container(
                width: 50 * _pulseController.value,
                height: 50 * _pulseController.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(1 - _pulseController.value),
                ),
              ),
            ),
            Icon(Icons.navigation_rounded, color: primaryColor, size: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundDecor(bool isDark) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: CircleAvatar(
              radius: 140,
              backgroundColor: const Color(
                0xFF6366F1,
              ).withOpacity(isDark ? 0.06 : 0.04),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: CircleAvatar(
              radius: 80,
              backgroundColor: const Color(
                0xFFA855F7,
              ).withOpacity(isDark ? 0.04 : 0.02),
            ),
          ),
        ],
      ),
    );
  }
}
